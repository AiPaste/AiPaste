import AppKit
import Foundation
import SwiftUI

enum ClipboardKind: String, Codable, Hashable {
    case text
    case code
    case link
    case pdf
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
    var codeLanguage: String?
    var sourceFileName: String?
    var imagePNGData: Data?
    var imageSize: PixelSize?
    var pdfData: Data?
    var pdfPreviewPNGData: Data?
    var pdfPageCount: Int?
    var pdfFileName: String?
    var groupID: String?
    var capturedAt: Date
    var bundleIdentifier: String?
    var appName: String
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        textContent: String,
        kind: ClipboardKind = .text,
        codeLanguage: String? = nil,
        sourceFileName: String? = nil,
        groupID: String? = nil,
        capturedAt: Date = .now,
        bundleIdentifier: String?,
        appName: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.textContent = textContent
        self.codeLanguage = codeLanguage
        self.sourceFileName = sourceFileName
        self.imagePNGData = nil
        self.imageSize = nil
        self.pdfData = nil
        self.pdfPreviewPNGData = nil
        self.pdfPageCount = nil
        self.pdfFileName = nil
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
        self.codeLanguage = nil
        self.sourceFileName = nil
        self.imagePNGData = imagePNGData
        self.imageSize = imageSize
        self.pdfData = nil
        self.pdfPreviewPNGData = nil
        self.pdfPageCount = nil
        self.pdfFileName = nil
        self.groupID = groupID
        self.capturedAt = capturedAt
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.isPinned = isPinned
    }

    init(
        id: UUID = UUID(),
        pdfData: Data,
        pdfPreviewPNGData: Data?,
        pdfPageCount: Int,
        pdfFileName: String?,
        groupID: String? = nil,
        capturedAt: Date = .now,
        bundleIdentifier: String?,
        appName: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = .pdf
        self.textContent = nil
        self.codeLanguage = nil
        self.sourceFileName = nil
        self.imagePNGData = nil
        self.imageSize = nil
        self.pdfData = pdfData
        self.pdfPreviewPNGData = pdfPreviewPNGData
        self.pdfPageCount = pdfPageCount
        self.pdfFileName = pdfFileName
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
        case .pdf:
            return "PDF"
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
            if let sourceFileName, !sourceFileName.isEmpty {
                return "\(sourceFileName) • \(lineCount) lines"
            }
            if let codeLanguage, !codeLanguage.isEmpty {
                return "\(codeLanguage) • \(lineCount) lines"
            }
            return "\(lineCount) lines"
        case .link:
            return linkHost ?? "Link"
        case .pdf:
            if let pdfPageCount {
                return pdfPageCount == 1 ? "1 page" : "\(pdfPageCount) pages"
            }
            if let pdfFileName, !pdfFileName.isEmpty {
                return pdfFileName
            }
            return "PDF"
        case .image:
            return imageSize?.label ?? "Image"
        }
    }

    var searchCorpus: String {
        [cardTitle, appName, textPreview, linkHost ?? "", pdfFileName ?? "", sourceFileName ?? "", codeLanguage ?? ""]
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

    var pdfPreviewImage: NSImage? {
        guard let pdfPreviewPNGData else { return nil }
        return NSImage(data: pdfPreviewPNGData)
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

    func matchesPDFPayload(_ data: Data, in groupID: String?) -> Bool {
        kind == .pdf && pdfData == data && self.groupID == groupID
    }

    static func detectKind(for text: String) -> ClipboardKind {
        detectMetadata(for: text, sourceFileName: nil).kind
    }

    static func detectMetadata(for text: String, sourceFileName: String?) -> (kind: ClipboardKind, codeLanguage: String?) {
        if URL.normalizedClipboardURL(from: text) != nil {
            return (.link, nil)
        }

        if let codeLanguage = detectCodeLanguage(for: text, sourceFileName: sourceFileName) {
            return (.code, codeLanguage)
        }

        return (isLikelyCode(text) ? .code : .text, nil)
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

    private static func detectCodeLanguage(for text: String, sourceFileName: String?) -> String? {
        if let sourceFileName,
           let language = languageForFileName(sourceFileName) {
            return language
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let fencedLanguage = fencedCodeLanguage(from: trimmed) {
            return fencedLanguage
        }

        let lowercased = trimmed.lowercased()

        let languageRules: [(String, [String])] = [
            ("Swift", ["import swiftui", "import foundation", "let ", "var ", "struct ", "enum ", "protocol ", "guard ", "func "]),
            ("TypeScript", ["interface ", "type ", ": string", ": number", "export type", "import type", " as const"]),
            ("JavaScript", ["function ", "const ", "=>", "module.exports", "require(", "console.log("]),
            ("Python", ["def ", "import ", "from ", "print(", "elif ", "__name__ == \"__main__\""]),
            ("Shell", ["#!/bin/bash", "#!/bin/zsh", "#!/usr/bin/env bash", "#!/usr/bin/env zsh", "brew ", "curl ", "export ", "chmod "]),
            ("Go", ["package main", "func main()", "import (", "fmt."]),
            ("Rust", ["fn main()", "let mut ", "impl ", "use std::", "pub struct"]),
            ("Java", ["public class ", "private static", "public static void main", "import java."]),
            ("Kotlin", ["fun main(", "val ", "var ", "data class ", "package "]),
            ("SQL", ["select ", "insert into ", "update ", "delete from ", "create table ", "alter table "]),
            ("HTML", ["<!doctype html", "<html", "<div", "<span", "</"]),
            ("CSS", ["{", "}", "color:", "display:", "@media", ":root"]),
            ("JSON", ["{\"", "\":[", "\":", "\"}"]),
            ("YAML", [": ", "- ", "version:", "services:", "name:"])
        ]

        for (language, signals) in languageRules {
            let matchCount = signals.filter { lowercased.contains($0) }.count
            if matchCount >= 2 || (language != "JSON" && language != "YAML" && matchCount >= 1 && isLikelyCode(text)) {
                return language
            }
        }

        return nil
    }

    private static func fencedCodeLanguage(from text: String) -> String? {
        let pattern = #"^```([a-zA-Z0-9_+#-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let token = String(text[range]).lowercased()
        return languageForFenceToken(token)
    }

    private static func languageForFenceToken(_ token: String) -> String? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let mapping: [String: String] = [
            "swift": "Swift",
            "ts": "TypeScript",
            "tsx": "TypeScript",
            "typescript": "TypeScript",
            "js": "JavaScript",
            "jsx": "JavaScript",
            "javascript": "JavaScript",
            "py": "Python",
            "python": "Python",
            "sh": "Shell",
            "bash": "Shell",
            "zsh": "Shell",
            "shell": "Shell",
            "go": "Go",
            "rs": "Rust",
            "rust": "Rust",
            "java": "Java",
            "kt": "Kotlin",
            "kotlin": "Kotlin",
            "sql": "SQL",
            "html": "HTML",
            "css": "CSS",
            "json": "JSON",
            "yaml": "YAML",
            "yml": "YAML",
            "toml": "TOML",
            "xml": "XML"
        ]
        return mapping[normalized]
    }

    private static func languageForFileName(_ fileName: String) -> String? {
        let lowercased = fileName.lowercased()
        let url = URL(fileURLWithPath: lowercased)
        let ext = url.pathExtension
        guard !ext.isEmpty else { return nil }

        let mapping: [String: String] = [
            "swift": "Swift",
            "m": "Objective-C",
            "mm": "Objective-C++",
            "h": "C Header",
            "c": "C",
            "cc": "C++",
            "cpp": "C++",
            "cxx": "C++",
            "hpp": "C++ Header",
            "js": "JavaScript",
            "jsx": "JavaScript",
            "ts": "TypeScript",
            "tsx": "TypeScript",
            "py": "Python",
            "rb": "Ruby",
            "go": "Go",
            "rs": "Rust",
            "java": "Java",
            "kt": "Kotlin",
            "kts": "Kotlin",
            "scala": "Scala",
            "cs": "C#",
            "php": "PHP",
            "sh": "Shell",
            "bash": "Shell",
            "zsh": "Shell",
            "fish": "Fish",
            "sql": "SQL",
            "html": "HTML",
            "css": "CSS",
            "scss": "SCSS",
            "sass": "Sass",
            "less": "Less",
            "json": "JSON",
            "yaml": "YAML",
            "yml": "YAML",
            "toml": "TOML",
            "xml": "XML",
            "vue": "Vue",
            "svelte": "Svelte",
            "dart": "Dart",
            "lua": "Lua",
            "r": "R",
            "pl": "Perl"
        ]

        return mapping[ext]
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
