import AppKit
import Foundation
import SwiftUI

enum ClipboardKind: String, Codable, Hashable {
    case text
    case code
    case link
    case image
}

struct PixelSize: Codable, Hashable {
    let width: Int
    let height: Int

    var label: String {
        "\(width) × \(height)"
    }
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: ClipboardKind
    var textContent: String?
    var imagePNGData: Data?
    var imageSize: PixelSize?
    var groupID: String?
    var capturedAt: Date
    var bundleIdentifier: String?
    var appName: String
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        textContent: String,
        kind: ClipboardKind = .text,
        groupID: String? = nil,
        capturedAt: Date = .now,
        bundleIdentifier: String?,
        appName: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.textContent = textContent
        self.imagePNGData = nil
        self.imageSize = nil
        self.groupID = groupID
        self.capturedAt = capturedAt
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.isPinned = isPinned
    }

    init(
        id: UUID = UUID(),
        imagePNGData: Data,
        imageSize: PixelSize,
        groupID: String? = nil,
        capturedAt: Date = .now,
        bundleIdentifier: String?,
        appName: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = .image
        self.textContent = nil
        self.imagePNGData = imagePNGData
        self.imageSize = imageSize
        self.groupID = groupID
        self.capturedAt = capturedAt
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.isPinned = isPinned
    }

    var cardTitle: String {
        switch kind {
        case .text:
            return "Text"
        case .code:
            return "Code"
        case .link:
            return "Link"
        case .image:
            return "Image"
        }
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: capturedAt, relativeTo: .now)
    }

    var textPreview: String {
        textContent ?? ""
    }

    var previewLines: [String] {
        textPreview
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    var characterCount: Int {
        textPreview.count
    }

    var footerLabel: String {
        switch kind {
        case .text:
            return "\(characterCount) characters"
        case .code:
            return "\(lineCount) lines"
        case .link:
            return linkHost ?? "Link"
        case .image:
            return imageSize?.label ?? "Image"
        }
    }

    var searchCorpus: String {
        [cardTitle, appName, textPreview, linkHost ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var resolvedURL: URL? {
        guard kind == .link, let textContent else { return nil }
        return URL.normalizedClipboardURL(from: textContent)
    }

    var linkHost: String? {
        resolvedURL?.host()
    }

    var linkDisplayText: String {
        resolvedURL?.absoluteString ?? textPreview
    }

    var lineCount: Int {
        max(textPreview.split(whereSeparator: \.isNewline).count, textPreview.isEmpty ? 0 : 1)
    }

    var codePreview: String {
        let trimmed = textPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"), trimmed.hasSuffix("```") else { return textPreview }

        var lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { return textPreview }
        lines.removeFirst()
        if !lines.isEmpty, lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    var sourceStyle: SourceStyle {
        SourceStyle.resolve(bundleIdentifier: bundleIdentifier, appName: appName)
    }

    var image: NSImage? {
        guard let imagePNGData else { return nil }
        return NSImage(data: imagePNGData)
    }

    func appIcon() -> NSImage? {
        guard let bundleIdentifier else { return nil }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 54, height: 54)
        return icon
    }

    func matchesStringPayload(_ text: String, in groupID: String?) -> Bool {
        (kind == .text || kind == .code || kind == .link) && textContent == text && self.groupID == groupID
    }

    func matchesImagePayload(_ data: Data, in groupID: String?) -> Bool {
        kind == .image && imagePNGData == data && self.groupID == groupID
    }

    static func detectKind(for text: String) -> ClipboardKind {
        if URL.normalizedClipboardURL(from: text) != nil {
            return .link
        }

        return isLikelyCode(text) ? .code : .text
    }

    private static func isLikelyCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix("```") && trimmed.hasSuffix("```") {
            return true
        }

        if trimmed.range(of: #"^(?:\$|#|>)?\s*(git|swift|npm|pnpm|yarn|bun|python|python3|node|cargo|go|docker|kubectl|brew|curl|ssh|cd|ls|cp|mv|rm|mkdir|touch)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        let lines = trimmed.split(whereSeparator: \.isNewline)
        let hasMultipleLines = lines.count >= 2
        let indentedLines = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }.count
        let keywordMatches = [
            #"\b(func|class|struct|enum|protocol|extension|let|var|const|import|from|def|return|async|await|if|else|for|while|switch|case|guard|SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER)\b"#,
            #"[{};<>]|=>|->|::|</|/>"#,
        ].filter { trimmed.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }.count

        if hasMultipleLines && (keywordMatches >= 1 || indentedLines >= 1) {
            return true
        }

        if keywordMatches >= 2 {
            return true
        }

        return false
    }
}

private extension URL {
    static func normalizedClipboardURL(from rawText: String) -> URL? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host() != nil {
            return url
        }

        let prefixed = "https://\(trimmed)"
        if let url = URL(string: prefixed), url.host() != nil, trimmed.contains(".") {
            return url
        }

        return nil
    }
}

struct SourceStyle: Hashable {
    let id: String
    let accent: Color
    let secondaryAccent: Color
    let icon: String
    let label: String
    let tint: Color
    let dot: Color

    static func resolve(bundleIdentifier: String?, appName: String) -> SourceStyle {
        let needle = [bundleIdentifier ?? "", appName]
            .joined(separator: " ")
            .lowercased()

        if needle.contains("chrome") {
            return SourceStyle(
                id: "chrome",
                accent: Color(red: 0.28, green: 0.51, blue: 0.93),
                secondaryAccent: Color(red: 0.31, green: 0.54, blue: 0.95),
                icon: "globe",
                label: "chrome",
                tint: Color.white,
                dot: Color(red: 0.99, green: 0.28, blue: 0.28)
            )
        }

        if needle.contains("telegram") || needle.contains("tg") {
            return SourceStyle(
                id: "telegram",
                accent: Color(red: 0.15, green: 0.78, blue: 0.72),
                secondaryAccent: Color(red: 0.12, green: 0.76, blue: 0.74),
                icon: "paperplane.fill",
                label: "tg",
                tint: Color.white,
                dot: Color(red: 0.20, green: 0.83, blue: 0.36)
            )
        }

        if needle.contains("cursor") {
            return SourceStyle(
                id: "cursor",
                accent: Color(red: 1.00, green: 0.63, blue: 0.19),
                secondaryAccent: Color(red: 1.00, green: 0.63, blue: 0.19),
                icon: "cursorarrow.motionlines",
                label: "cursor",
                tint: Color.black.opacity(0.82),
                dot: Color(red: 1.00, green: 0.63, blue: 0.19)
            )
        }

        if needle.contains("terminal") || needle.contains("iterm") || needle.contains("warp") {
            return SourceStyle(
                id: "terminal",
                accent: Color(red: 0.27, green: 0.45, blue: 0.93),
                secondaryAccent: Color(red: 0.23, green: 0.40, blue: 0.84),
                icon: "terminal.fill",
                label: "terminal",
                tint: Color.white,
                dot: Color(red: 1.00, green: 0.27, blue: 0.31)
            )
        }

        if needle.contains("code") || needle.contains("xcode") {
            return SourceStyle(
                id: "code",
                accent: Color(red: 0.13, green: 0.76, blue: 0.70),
                secondaryAccent: Color(red: 0.11, green: 0.73, blue: 0.66),
                icon: "chevron.left.forwardslash.chevron.right",
                label: "security-key",
                tint: Color.white,
                dot: Color(red: 1.00, green: 0.27, blue: 0.31)
            )
        }

        if needle.contains("safari") {
            return SourceStyle(
                id: "safari",
                accent: Color(red: 0.28, green: 0.51, blue: 0.93),
                secondaryAccent: Color(red: 0.31, green: 0.54, blue: 0.95),
                icon: "safari.fill",
                label: "proxy-staging",
                tint: Color.white,
                dot: Color(red: 0.75, green: 0.75, blue: 0.79)
            )
        }

        return SourceStyle(
            id: "generic",
            accent: Color(red: 0.28, green: 0.51, blue: 0.93),
            secondaryAccent: Color(red: 0.31, green: 0.54, blue: 0.95),
            icon: "doc.on.clipboard.fill",
            label: appName.lowercased(),
            tint: Color.white,
            dot: Color(red: 1.00, green: 0.27, blue: 0.31)
        )
    }
}
