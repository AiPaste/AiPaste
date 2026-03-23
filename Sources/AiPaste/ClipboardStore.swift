import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published var searchText = ""
    @Published var selectedSourceID = "all"
    @Published private(set) var lastCopiedItemID: UUID?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let maxItems = 80
    private let persistenceURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        lastChangeCount = pasteboard.changeCount
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = appSupport.appendingPathComponent("AiPaste", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistenceURL = directory.appendingPathComponent("clipboard-history.json")

        load()
        startMonitoring()
    }

    var visibleItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = items.filter { item in
            let matchesSource = selectedSourceID == "all" || item.sourceStyle.id == selectedSourceID
            guard matchesSource else { return false }
            guard !query.isEmpty else { return true }
            return item.searchCorpus.localizedCaseInsensitiveContains(query)
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.capturedAt > rhs.capturedAt
        }
    }

    var filterTabs: [SourceStyle] {
        var deduped: [String: SourceStyle] = [:]
        items.forEach { deduped[$0.sourceStyle.id] = $0.sourceStyle }
        return deduped.values.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureIfNeeded()
            }
        }
    }

    func captureCurrentClipboard() {
        let previous = lastChangeCount
        lastChangeCount = -1
        captureIfNeeded()
        if lastCopiedItemID == nil {
            lastChangeCount = previous
        }
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            if let textContent = item.textContent {
                pasteboard.setString(textContent, forType: .string)
            }
        case .image:
            if let image = item.image {
                pasteboard.writeObjects([image])
            }
        }

        lastChangeCount = pasteboard.changeCount
        lastCopiedItemID = item.id
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        persist()
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    private func captureIfNeeded() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Clipboard"
        let bundleIdentifier = app?.bundleIdentifier

        if let imagePayload = currentImagePayload() {
            upsertImageItem(imagePayload.data, size: imagePayload.size, appName: appName, bundleIdentifier: bundleIdentifier)
            persist()
            return
        }

        guard let rawString = pasteboard.string(forType: .string) else { return }
        let normalized = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        upsertTextItem(normalized, appName: appName, bundleIdentifier: bundleIdentifier)
        persist()
    }

    private func upsertTextItem(_ text: String, appName: String, bundleIdentifier: String?) {
        if let existingIndex = items.firstIndex(where: { $0.matchesTextPayload(text) }) {
            var existing = items.remove(at: existingIndex)
            existing.capturedAt = .now
            existing.appName = appName
            existing.bundleIdentifier = bundleIdentifier
            items.insert(existing, at: 0)
        } else {
            items.insert(
                ClipboardItem(
                    textContent: text,
                    capturedAt: .now,
                    bundleIdentifier: bundleIdentifier,
                    appName: appName
                ),
                at: 0
            )
        }
        trimIfNeeded()
    }

    private func upsertImageItem(_ data: Data, size: PixelSize, appName: String, bundleIdentifier: String?) {
        if let existingIndex = items.firstIndex(where: { $0.matchesImagePayload(data) }) {
            var existing = items.remove(at: existingIndex)
            existing.capturedAt = .now
            existing.appName = appName
            existing.bundleIdentifier = bundleIdentifier
            existing.imageSize = size
            items.insert(existing, at: 0)
        } else {
            items.insert(
                ClipboardItem(
                    imagePNGData: data,
                    imageSize: size,
                    capturedAt: .now,
                    bundleIdentifier: bundleIdentifier,
                    appName: appName
                ),
                at: 0
            )
        }
        trimIfNeeded()
    }

    private func currentImagePayload() -> (data: Data, size: PixelSize)? {
        guard let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            return nil
        }
        guard let pngData = image.pngData else { return nil }
        let size = PixelSize(width: Int(image.size.width), height: Int(image.size.height))
        return (pngData, size)
    }

    private func trimIfNeeded() {
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL) else { return }
        guard let savedItems = try? decoder.decode([ClipboardItem].self, from: data) else { return }
        items = savedItems
    }

    private func persist() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
