import AppKit
import ApplicationServices
import Combine
import Foundation
import OSLog
import PDFKit
import UniformTypeIdentifiers

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

struct ClipboardWriteResult {
    let success: Bool
    let recommendedPasteDelay: TimeInterval

    var activationTimeout: TimeInterval {
        max(recommendedPasteDelay + 0.25, 0.35)
    }
}

@MainActor
final class ClipboardStore: ObservableObject {
    private struct TextCaptureContext {
        let sourceFileName: String?
    }

    private struct PasteboardWriteProfile {
        let recommendedPasteDelay: TimeInterval
        let verificationTimeout: TimeInterval

        static func resolve(forPayloadSize payloadSize: Int) -> PasteboardWriteProfile {
            switch payloadSize {
            case 0..<128_000:
                return PasteboardWriteProfile(recommendedPasteDelay: 0.08, verificationTimeout: 0.20)
            case 128_000..<512_000:
                return PasteboardWriteProfile(recommendedPasteDelay: 0.14, verificationTimeout: 0.35)
            case 512_000..<2_000_000:
                return PasteboardWriteProfile(recommendedPasteDelay: 0.22, verificationTimeout: 0.60)
            case 2_000_000..<8_000_000:
                return PasteboardWriteProfile(recommendedPasteDelay: 0.35, verificationTimeout: 1.00)
            default:
                return PasteboardWriteProfile(recommendedPasteDelay: 0.55, verificationTimeout: 1.60)
            }
        }
    }

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
    private var pendingChangeCount: Int?
    private var pendingCaptureAttempts = 0
    private var pendingRetryWorkItem: DispatchWorkItem?
    private let maxItems = 80
    private let maxPendingCaptureAttempts = 6
    private let pendingRetryDelay: TimeInterval = 0.12
    private let persistenceURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cloudStore = NSUbiquitousKeyValueStore.default
    private let cloudStateKey = "icloud.clipboardState"
    private let deviceID = Host.current().localizedName ?? UUID().uuidString
    private var isApplyingCloudState = false
    private let monitoringEnabled: Bool
    private let logger = Logger(subsystem: "AiPaste", category: "ClipboardStore")

    init(enableMonitoring: Bool = true) {
        monitoringEnabled = enableMonitoring
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
        if monitoringEnabled {
            startMonitoring()
        }
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
        clearPendingCaptureRetry()
        captureIfNeeded()
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = previous
        }
    }

    @discardableResult
    func copy(_ item: ClipboardItem) -> ClipboardWriteResult {
        let payloadSize = payloadSize(for: item)
        let writeProfile = PasteboardWriteProfile.resolve(forPayloadSize: payloadSize)

        for attempt in 1...3 {
            let baselineChangeCount = pasteboard.changeCount
            guard performPasteboardWrite(for: item) else {
                logger.error("pasteboard write attempt \(attempt, privacy: .public) failed for item \(item.id.uuidString, privacy: .public)")
                continue
            }

            if waitForPasteboardWrite(of: item, after: baselineChangeCount, verificationTimeout: writeProfile.verificationTimeout) {
                promote(item)
                lastChangeCount = pasteboard.changeCount
                lastCopiedItemID = item.id
                persist()
                logger.debug("pasteboard write succeeded for item \(item.id.uuidString, privacy: .public) size=\(payloadSize, privacy: .public)")
                return ClipboardWriteResult(success: true, recommendedPasteDelay: writeProfile.recommendedPasteDelay)
            }

            logger.error("pasteboard write verification attempt \(attempt, privacy: .public) timed out for item \(item.id.uuidString, privacy: .public)")
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.04 * Double(attempt)))
        }

        return ClipboardWriteResult(success: false, recommendedPasteDelay: writeProfile.recommendedPasteDelay)
    }

    @discardableResult
    func copyTextToPasteboard(_ text: String) -> Bool {
        let baselineChangeCount = pasteboard.changeCount
        let writeProfile = PasteboardWriteProfile.resolve(forPayloadSize: text.utf8.count)
        let result = writeTextPayload(text)
        if !result {
            logger.error("copyTextToPasteboard failed for payload size=\(text.utf8.count, privacy: .public)")
        }
        return result && waitForTextPasteboardWrite(text, after: baselineChangeCount, verificationTimeout: writeProfile.verificationTimeout)
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

    func reloadFromDisk() {
        items = []
        groups = []
        load()
        applyRetentionPolicy()
    }

    private func promote(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items.remove(at: index)
        updated.capturedAt = .now
        items.insert(updated, at: 0)
    }

    private func captureIfNeeded() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            clearPendingCaptureRetry()
            return
        }

        if pendingChangeCount != currentChangeCount {
            pendingChangeCount = currentChangeCount
            pendingCaptureAttempts = 0
        }

        guard performCaptureAttempt() else {
            pendingCaptureAttempts += 1
            guard pendingCaptureAttempts < maxPendingCaptureAttempts else {
                lastChangeCount = currentChangeCount
                clearPendingCaptureRetry()
                return
            }

            schedulePendingCaptureRetry()
            return
        }

        lastChangeCount = currentChangeCount
        clearPendingCaptureRetry()
    }

    private func performCaptureAttempt() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Clipboard"
        let bundleIdentifier = app?.bundleIdentifier
        let currentGroupID = groups.contains(where: { $0.id == selectedSourceID }) ? selectedSourceID : nil
        let privacy = PrivacySettingsStore.shared

        if privacy.isIgnored(bundleIdentifier: bundleIdentifier) {
            return true
        }

        if let pdfPayload = currentPDFPayload() {
            upsertPDFItem(
                pdfPayload.data,
                previewPNGData: pdfPayload.previewPNGData,
                pageCount: pdfPayload.pageCount,
                fileName: pdfPayload.fileName,
                groupID: currentGroupID,
                appName: appName,
                bundleIdentifier: bundleIdentifier
            )
            SoundEffectPlayer.shared.play(.capture)
            persist()
            return true
        }

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
            return true
        }

        guard let rawString = currentTextPayload() else { return false }
        let normalized = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }
        if shouldIgnoreTextCapture(normalized, privacy: privacy) {
            return true
        }
        let textContext = currentTextCaptureContext(for: app)
        upsertTextItem(
            normalized,
            sourceFileName: textContext?.sourceFileName,
            groupID: currentGroupID,
            appName: appName,
            bundleIdentifier: bundleIdentifier
        )
        SoundEffectPlayer.shared.play(.capture)
        persist()
        return true
    }

    private func upsertTextItem(
        _ text: String,
        sourceFileName: String?,
        groupID: String?,
        appName: String,
        bundleIdentifier: String?
    ) {
        let metadata = ClipboardItem.detectMetadata(for: text, sourceFileName: sourceFileName)

        if let existingIndex = items.firstIndex(where: { $0.matchesStringPayload(text, in: groupID) }) {
            var existing = items.remove(at: existingIndex)
            existing.capturedAt = .now
            existing.appName = appName
            existing.bundleIdentifier = bundleIdentifier
            existing.kind = metadata.kind
            existing.codeLanguage = metadata.codeLanguage
            existing.sourceFileName = sourceFileName
            items.insert(existing, at: 0)
        } else {
            items.insert(
                ClipboardItem(
                    textContent: text,
                    kind: metadata.kind,
                    codeLanguage: metadata.codeLanguage,
                    sourceFileName: sourceFileName,
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

    private func upsertPDFItem(
        _ data: Data,
        previewPNGData: Data?,
        pageCount: Int,
        fileName: String?,
        groupID: String?,
        appName: String,
        bundleIdentifier: String?
    ) {
        if let existingIndex = items.firstIndex(where: { $0.matchesPDFPayload(data, in: groupID) }) {
            var existing = items.remove(at: existingIndex)
            existing.capturedAt = .now
            existing.appName = appName
            existing.bundleIdentifier = bundleIdentifier
            existing.pdfPreviewPNGData = previewPNGData
            existing.pdfPageCount = pageCount
            existing.pdfFileName = fileName
            items.insert(existing, at: 0)
        } else {
            items.insert(
                ClipboardItem(
                    pdfData: data,
                    pdfPreviewPNGData: previewPNGData,
                    pdfPageCount: pageCount,
                    pdfFileName: fileName,
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

    private func currentPDFPayload() -> (data: Data, previewPNGData: Data?, pageCount: Int, fileName: String?)? {
        if let fileURL = currentPDFFileURL(),
           let data = try? Data(contentsOf: fileURL),
           let metadata = makePDFMetadata(from: data) {
            return (
                data: data,
                previewPNGData: metadata.previewPNGData,
                pageCount: metadata.pageCount,
                fileName: fileURL.lastPathComponent
            )
        }

        if let data = pasteboard.data(forType: .pdf),
           let metadata = makePDFMetadata(from: data) {
            return (
                data: data,
                previewPNGData: metadata.previewPNGData,
                pageCount: metadata.pageCount,
                fileName: nil
            )
        }

        return nil
    }

    private func currentImagePayload() -> (data: Data, size: PixelSize)? {
        guard let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            return nil
        }
        guard let pngData = image.pngData else { return nil }
        let size = PixelSize(width: Int(image.size.width), height: Int(image.size.height))
        return (pngData, size)
    }

    private func payloadSize(for item: ClipboardItem) -> Int {
        switch item.kind {
        case .text, .code, .link:
            return item.textContent?.utf8.count ?? 0
        case .pdf:
            return item.pdfData?.count ?? 0
        case .image:
            return item.imagePNGData?.count ?? 0
        }
    }

    private func performPasteboardWrite(for item: ClipboardItem) -> Bool {
        switch item.kind {
        case .text, .code, .link:
            guard let textContent = item.textContent else { return false }
            return writeTextPayload(textContent)
        case .pdf:
            guard let pdfData = item.pdfData else { return false }
            return writeDataPayload(pdfData, forTypes: [.pdf])
        case .image:
            guard let pngData = item.imagePNGData else { return false }
            return writeImagePayload(pngData, image: item.image)
        }
    }

    private func writeTextPayload(_ text: String) -> Bool {
        let item = NSPasteboardItem()
        var hasRepresentation = false

        if item.setString(text, forType: .string) {
            hasRepresentation = true
        }

        let plainTextTypes = preferredPlainTextTypes
        for type in plainTextTypes {
            if item.setString(text, forType: type) {
                hasRepresentation = true
            }
        }

        if let utf8Data = text.data(using: .utf8) {
            if item.setData(utf8Data, forType: NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier)) {
                hasRepresentation = true
            }
            if item.setData(utf8Data, forType: NSPasteboard.PasteboardType(UTType.plainText.identifier)) {
                hasRepresentation = true
            }
        }

        if let utf16Data = text.data(using: .utf16) {
            if item.setData(utf16Data, forType: NSPasteboard.PasteboardType(UTType.utf16ExternalPlainText.identifier)) {
                hasRepresentation = true
            }
        }

        guard hasRepresentation else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }

    private func writeDataPayload(_ data: Data, forTypes types: [NSPasteboard.PasteboardType]) -> Bool {
        let item = NSPasteboardItem()
        var hasRepresentation = false

        for type in types {
            if item.setData(data, forType: type) {
                hasRepresentation = true
            }
        }

        guard hasRepresentation else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }

    private func writeImagePayload(_ pngData: Data, image: NSImage?) -> Bool {
        let item = NSPasteboardItem()
        var hasRepresentation = false

        if item.setData(pngData, forType: NSPasteboard.PasteboardType(UTType.png.identifier)) {
            hasRepresentation = true
        }

        if let tiffData = image?.tiffRepresentation,
           item.setData(tiffData, forType: .tiff) {
            hasRepresentation = true
        }

        guard hasRepresentation else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }

    private func waitForPasteboardWrite(of item: ClipboardItem, after baselineChangeCount: Int, verificationTimeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(verificationTimeout)

        while Date() < deadline {
            if pasteboard.changeCount > baselineChangeCount, verifyPasteboardPayload(for: item) {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }

        return false
    }

    private func waitForTextPasteboardWrite(_ text: String, after baselineChangeCount: Int, verificationTimeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(verificationTimeout)

        while Date() < deadline {
            if pasteboard.changeCount > baselineChangeCount,
               let pastedText = currentTextPayload(),
               pastedText == text {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }

        return false
    }

    private func verifyPasteboardPayload(for item: ClipboardItem) -> Bool {
        switch item.kind {
        case .text, .code, .link:
            guard let textContent = item.textContent else { return false }
            return currentTextPayload() == textContent
        case .pdf:
            guard let pdfData = item.pdfData else { return false }
            return pasteboard.data(forType: .pdf) == pdfData
        case .image:
            guard let pngData = item.imagePNGData else { return false }
            return pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.png.identifier)) == pngData
        }
    }
    private func currentTextPayload() -> String? {
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return string
        }

        for type in preferredPlainTextTypes {
            if let string = pasteboard.string(forType: type), !string.isEmpty {
                return string
            }

            guard let data = pasteboard.data(forType: type),
                  let decoded = decodePlainTextData(data),
                  !decoded.isEmpty else {
                continue
            }
            return decoded
        }

        if let rtfString = attributedString(
            for: .rtf,
            documentType: .rtf
        )?.string,
           !rtfString.isEmpty {
            return rtfString
        }

        if let htmlString = attributedString(
            for: .html,
            documentType: .html
        )?.string,
           !htmlString.isEmpty {
            return htmlString
        }

        return nil
    }

    private var preferredPlainTextTypes: [NSPasteboard.PasteboardType] {
        [
            NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier),
            NSPasteboard.PasteboardType(UTType.utf16ExternalPlainText.identifier),
            NSPasteboard.PasteboardType(UTType.plainText.identifier),
            NSPasteboard.PasteboardType(UTType.text.identifier)
        ]
    }

    private func decodePlainTextData(_ data: Data) -> String? {
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .unicode,
            .ascii
        ]

        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }

        return nil
    }

    private func attributedString(
        for type: NSPasteboard.PasteboardType,
        documentType: NSAttributedString.DocumentType
    ) -> NSAttributedString? {
        guard let data = pasteboard.data(forType: type) else { return nil }

        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: documentType,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }

    private func schedulePendingCaptureRetry() {
        guard pendingRetryWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.pendingRetryWorkItem = nil
                self?.captureIfNeeded()
            }
        }

        pendingRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + pendingRetryDelay, execute: workItem)
    }

    private func clearPendingCaptureRetry() {
        pendingRetryWorkItem?.cancel()
        pendingRetryWorkItem = nil
        pendingChangeCount = nil
        pendingCaptureAttempts = 0
    }

    private func currentTextCaptureContext(for app: NSRunningApplication?) -> TextCaptureContext? {
        guard let app,
              isLikelyCodeEditor(appName: app.localizedName ?? "", bundleIdentifier: app.bundleIdentifier),
              let focusedWindowElement = focusedWindowElement(for: app.processIdentifier) else {
            return nil
        }

        if let documentURLString = accessibilityStringAttribute(kAXDocumentAttribute as CFString, element: focusedWindowElement),
           let fileName = fileName(fromDocumentValue: documentURLString) {
            return TextCaptureContext(sourceFileName: fileName)
        }

        if let title = accessibilityStringAttribute(kAXTitleAttribute as CFString, element: focusedWindowElement),
           let fileName = fileName(fromWindowTitle: title) {
            return TextCaptureContext(sourceFileName: fileName)
        }

        return nil
    }

    private func isLikelyCodeEditor(appName: String, bundleIdentifier: String?) -> Bool {
        let needle = [appName, bundleIdentifier ?? ""]
            .joined(separator: " ")
            .lowercased()

        let editorSignals = [
            "idea", "intellij", "jetbrains", "pycharm", "goland", "webstorm", "rubymine",
            "clion", "android studio", "xcode", "visual studio code", "cursor", "zed",
            "nova", "sublime", "bbedit", "code"
        ]

        return editorSignals.contains(where: { needle.contains($0) })
    }

    private func focusedWindowElement(for processID: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processID)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func accessibilityStringAttribute(_ attribute: CFString, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func fileName(fromDocumentValue value: String) -> String? {
        if let url = URL(string: value), url.isFileURL {
            return url.lastPathComponent
        }

        let documentURL = URL(fileURLWithPath: value)
        if !documentURL.lastPathComponent.isEmpty {
            return documentURL.lastPathComponent
        }

        return nil
    }

    private func fileName(fromWindowTitle title: String) -> String? {
        let separators = [" — ", " – ", " - ", " • ", " · "]
        let candidates = separators.flatMap { separator in
            title.components(separatedBy: separator)
        } + [title]

        let pattern = #"[A-Za-z0-9._-]+\.[A-Za-z0-9#+-]{1,8}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range),
                  let swiftRange = Range(match.range, in: trimmed) else {
                continue
            }
            return String(trimmed[swiftRange])
        }

        return nil
    }

    private func currentPDFFileURL() -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        return urls?.first(where: { $0.pathExtension.localizedCaseInsensitiveCompare("pdf") == .orderedSame })
    }

    private func makePDFMetadata(from data: Data) -> (previewPNGData: Data?, pageCount: Int)? {
        guard let document = PDFDocument(data: data) else { return nil }
        let pageCount = max(document.pageCount, 1)
        let previewPNGData: Data?

        if let firstPage = document.page(at: 0) {
            let previewImage = firstPage.thumbnail(of: NSSize(width: 420, height: 300), for: .cropBox)
            previewPNGData = previewImage.pngData
        } else {
            previewPNGData = nil
        }

        return (previewPNGData, pageCount)
    }

    private func trimIfNeeded() {
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
    }

    private func shouldIgnoreTextCapture(_ text: String, privacy: PrivacySettingsStore) -> Bool {
        if privacy.ignoreTransientContent, isTransientContent(text) {
            return true
        }
        if privacy.ignoreConfidentialContent, isConfidentialContent(text) {
            return true
        }
        return false
    }

    private func isTransientContent(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^\d{4,8}$"#, options: .regularExpression) != nil {
            return true
        }

        let lowercase = trimmed.lowercased()
        let transientSignals = [
            "one-time code", "verification code", "otp", "2fa", "two-factor",
            "temporary code", "expires in", "valid for", "auth code"
        ]
        return transientSignals.contains { lowercase.contains($0) }
    }

    private func isConfidentialContent(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowercase = trimmed.lowercased()

        if containsHighConfidenceSecret(in: trimmed) {
            return true
        }

        if containsStructuredSecretAssignment(in: trimmed) {
            return true
        }

        let keywordSignals = [
            "password", "passcode", "secret", "api_key", "apikey", "private key",
            "access token", "refresh token", "bearer ", "session token"
        ]

        if looksLikeStructuredCodeOrConfig(trimmed) {
            return false
        }

        return keywordSignals.contains { lowercase.contains($0) }
    }

    private func containsHighConfidenceSecret(in text: String) -> Bool {
        let regexes = [
            #"(?i)sk-[a-z0-9]{20,}"#,
            #"(?i)ghp_[a-z0-9]{20,}"#,
            #"eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9._-]+\.[a-zA-Z0-9._-]+"#,
            #"-----BEGIN [A-Z ]+PRIVATE KEY-----"#
        ]

        return regexes.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private func containsStructuredSecretAssignment(in text: String) -> Bool {
        let patterns = [
            #"""(?is)<\s*(password|passcode|secret|api[_-]?key|apikey|access[_ -]?token|refresh[_ -]?token|session[_ -]?token)\s*>\s*([^<]{1,512}?)\s*</\s*\1\s*>"""#,
            #"""(?im)["']?(password|passcode|secret|api[_-]?key|apikey|access[_ -]?token|refresh[_ -]?token|session[_ -]?token)["']?\s*[:=]\s*["']?([^"'\s,;<>{}]{1,512})"""#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                guard match.numberOfRanges >= 3,
                      let valueRange = Range(match.range(at: 2), in: text) else {
                    continue
                }

                let value = String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isLikelySensitiveValue(value) {
                    return true
                }
            }
        }

        return false
    }

    private func isLikelySensitiveValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let normalized = trimmed.lowercased()
        let placeholderValues: Set<String> = [
            "password", "passcode", "secret", "changeme", "changeit", "example",
            "demo", "sample", "test", "testing", "localhost", "local", "root",
            "admin", "advent"
        ]

        if placeholderValues.contains(normalized) {
            return false
        }

        if containsHighConfidenceSecret(in: trimmed) {
            return true
        }

        let isLongToken = trimmed.count >= 20
            && trimmed.range(of: #"^[A-Za-z0-9_\-\.=+/]+$"#, options: .regularExpression) != nil
        if isLongToken {
            return true
        }

        let hasUppercase = trimmed.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = trimmed.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigits = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbols = trimmed.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
        let characterClasses = [hasUppercase, hasLowercase, hasDigits, hasSymbols].filter { $0 }.count

        if trimmed.count >= 8 && characterClasses >= 2 {
            return true
        }

        return false
    }

    private func looksLikeStructuredCodeOrConfig(_ text: String) -> Bool {
        ClipboardItem.detectKind(for: text) == .code
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
            } else if cloudItem.kind == .text || cloudItem.kind == .code || cloudItem.kind == .link {
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
            .filter { $0.kind == .text || $0.kind == .code || $0.kind == .link }
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
