import AppKit
import Combine
import Foundation

enum GroupColorToken: String, Codable, CaseIterable, Hashable {
    case red
    case orange
    case yellow
    case gray
    case green
    case blue
    case purple
    case pink

    var color: ColorValue {
        switch self {
        case .red:
            return ColorValue(red: 1.00, green: 0.27, blue: 0.31)
        case .orange:
            return ColorValue(red: 1.00, green: 0.63, blue: 0.19)
        case .yellow:
            return ColorValue(red: 0.98, green: 0.76, blue: 0.08)
        case .gray:
            return ColorValue(red: 0.75, green: 0.75, blue: 0.79)
        case .green:
            return ColorValue(red: 0.20, green: 0.83, blue: 0.36)
        case .blue:
            return ColorValue(red: 0.15, green: 0.56, blue: 0.96)
        case .purple:
            return ColorValue(red: 0.77, green: 0.24, blue: 0.92)
        case .pink:
            return ColorValue(red: 1.00, green: 0.24, blue: 0.47)
        }
    }
}

struct ClipboardGroup: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var colorToken: GroupColorToken
}

private struct PersistedClipboardState: Codable {
    var items: [ClipboardItem]
    var groups: [ClipboardGroup]
}

private struct CloudClipboardState: Codable {
    var items: [ClipboardItem]
    var groups: [ClipboardGroup]
    var updatedAt: Date
    var deviceID: String
}

struct ColorValue: Hashable {
    let red: Double
    let green: Double
    let blue: Double
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var groups: [ClipboardGroup] = []
    @Published var searchText = ""
    @Published var selectedSourceID = "all"
    @Published private(set) var lastCopiedItemID: UUID?
    @Published private(set) var iCloudSyncEnabled = UserDefaults.standard.object(forKey: AppPreferences.iCloudSync) as? Bool ?? true
    @Published private(set) var lastSyncDate: Date?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let maxItems = 80
    private let persistenceURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cloudStore = NSUbiquitousKeyValueStore.default
    private let cloudStateKey = "icloud.clipboardState"
    private let deviceID = Host.current().localizedName ?? UUID().uuidString
    private var isApplyingCloudState = false

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
        applyRetentionPolicy()
        configureCloudSync()
        startMonitoring()
    }

    var visibleItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = items.filter { item in
            let matchesSource: Bool
            if selectedSourceID == "all" {
                matchesSource = true
            } else if groups.contains(where: { $0.id == selectedSourceID }) {
                matchesSource = item.groupID == selectedSourceID
            } else {
                matchesSource = item.sourceStyle.id == selectedSourceID
            }
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

    func group(for id: String?) -> ClipboardGroup? {
        guard let id else { return nil }
        return groups.first(where: { $0.id == id })
    }

    func createGroup() {
        let index = groups.count + 1
        let token = GroupColorToken.allCases[groups.count % GroupColorToken.allCases.count]
        let group = ClipboardGroup(
            id: UUID().uuidString,
            title: "group-\(index)",
            colorToken: token
        )
        groups.append(group)
        selectedSourceID = group.id
        persist()
    }

    func renameGroup(id: String, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index].title = trimmed
        persist()
    }

    func updateGroupColor(id: String, token: GroupColorToken) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index].colorToken = token
        persist()
    }

    func deleteGroup(id: String) {
        groups.removeAll { $0.id == id }
        for index in items.indices where items[index].groupID == id {
            items[index].groupID = nil
        }
        if selectedSourceID == id {
            selectedSourceID = "all"
        }
        persist()
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
        promote(item)
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
        persist()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        persist()
    }

    func move(_ item: ClipboardItem, toGroupID groupID: String?) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].groupID = groupID
        items[index].capturedAt = .now

        let movedItem = items.remove(at: index)
        items.insert(movedItem, at: 0)
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

    func setICloudSync(_ enabled: Bool) {
        iCloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: AppPreferences.iCloudSync)

        if enabled {
            configureCloudSync()
            pushCloudState()
        }
    }

    func setHistoryRetention(_ retention: HistoryRetention) {
        UserDefaults.standard.set(retention.rawValue, forKey: AppPreferences.historyRetention)
        applyRetentionPolicy()
        persist()
    }

    private func promote(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items.remove(at: index)
        updated.capturedAt = .now
        items.insert(updated, at: 0)
    }

    private func captureIfNeeded() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Clipboard"
        let bundleIdentifier = app?.bundleIdentifier
        let currentGroupID = groups.contains(where: { $0.id == selectedSourceID }) ? selectedSourceID : nil

        if let imagePayload = currentImagePayload() {
            upsertImageItem(
                imagePayload.data,
                size: imagePayload.size,
                groupID: currentGroupID,
                appName: appName,
                bundleIdentifier: bundleIdentifier
            )
            SoundEffectPlayer.shared.play(.capture)
            persist()
            return
        }

        guard let rawString = pasteboard.string(forType: .string) else { return }
        let normalized = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        upsertTextItem(
            normalized,
            groupID: currentGroupID,
            appName: appName,
            bundleIdentifier: bundleIdentifier
        )
        SoundEffectPlayer.shared.play(.capture)
        persist()
    }

    private func upsertTextItem(_ text: String, groupID: String?, appName: String, bundleIdentifier: String?) {
        if let existingIndex = items.firstIndex(where: { $0.matchesTextPayload(text, in: groupID) }) {
            var existing = items.remove(at: existingIndex)
            existing.capturedAt = .now
            existing.appName = appName
            existing.bundleIdentifier = bundleIdentifier
            items.insert(existing, at: 0)
        } else {
            items.insert(
                ClipboardItem(
                    textContent: text,
                    groupID: groupID,
                    capturedAt: .now,
                    bundleIdentifier: bundleIdentifier,
                    appName: appName
                ),
                at: 0
            )
        }
        trimIfNeeded()
    }

    private func upsertImageItem(_ data: Data, size: PixelSize, groupID: String?, appName: String, bundleIdentifier: String?) {
        if let existingIndex = items.firstIndex(where: { $0.matchesImagePayload(data, in: groupID) }) {
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
                    groupID: groupID,
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
        if let savedState = try? decoder.decode(PersistedClipboardState.self, from: data) {
            items = savedState.items
            groups = savedState.groups
            return
        }
        if let savedItems = try? decoder.decode([ClipboardItem].self, from: data) {
            items = savedItems
        }
    }

    private func persist() {
        applyRetentionPolicy()
        let state = PersistedClipboardState(items: items, groups: groups)
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
        pushCloudState()
    }

    private func configureCloudSync() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )

        guard iCloudSyncEnabled else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        cloudStore.synchronize()
        pullCloudState()
    }

    @objc private func handleCloudStoreDidChange(_ notification: Notification) {
        guard iCloudSyncEnabled else { return }
        pullCloudState()
    }

    private func pushCloudState() {
        guard iCloudSyncEnabled, !isApplyingCloudState else { return }

        let state = CloudClipboardState(
            items: cloudSyncItems(),
            groups: groups,
            updatedAt: .now,
            deviceID: deviceID
        )

        guard let data = try? encoder.encode(state),
              let string = String(data: data, encoding: .utf8) else { return }

        cloudStore.set(string, forKey: cloudStateKey)
        cloudStore.synchronize()
        lastSyncDate = state.updatedAt
    }

    private func pullCloudState() {
        guard iCloudSyncEnabled,
              let string = cloudStore.string(forKey: cloudStateKey),
              let data = string.data(using: .utf8),
              let state = try? decoder.decode(CloudClipboardState.self, from: data) else { return }

        guard state.deviceID != deviceID || state.updatedAt > (lastSyncDate ?? .distantPast) else { return }

        isApplyingCloudState = true
        defer { isApplyingCloudState = false }

        groups = state.groups
        mergeCloudItems(state.items)
        lastSyncDate = state.updatedAt
        applyRetentionPolicy()

        let persistedState = PersistedClipboardState(items: items, groups: groups)
        if let localData = try? encoder.encode(persistedState) {
            try? localData.write(to: persistenceURL, options: .atomic)
        }
    }

    private func mergeCloudItems(_ cloudItems: [ClipboardItem]) {
        var merged = items

        for cloudItem in cloudItems {
            if let index = merged.firstIndex(where: { $0.id == cloudItem.id }) {
                if merged[index].capturedAt < cloudItem.capturedAt {
                    merged[index] = cloudItem
                }
            } else if cloudItem.kind == .text {
                merged.append(cloudItem)
            }
        }

        items = merged.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.capturedAt > rhs.capturedAt
        }
        trimIfNeeded()
    }

    private func cloudSyncItems() -> [ClipboardItem] {
        items
            .filter { $0.kind == .text }
            .prefix(40)
            .map { item in
                var syncedItem = item
                if let text = syncedItem.textContent, text.count > 4000 {
                    syncedItem.textContent = String(text.prefix(4000))
                }
                syncedItem.imagePNGData = nil
                syncedItem.imageSize = nil
                return syncedItem
            }
    }

    private func applyRetentionPolicy() {
        guard let maxAge = currentHistoryRetention.maxAge else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        items.removeAll { !$0.isPinned && $0.capturedAt < cutoff }
    }

    private var currentHistoryRetention: HistoryRetention {
        let rawValue = UserDefaults.standard.object(forKey: AppPreferences.historyRetention) as? Int ?? HistoryRetention.month.rawValue
        return HistoryRetention(rawValue: rawValue) ?? .month
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
