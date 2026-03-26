import AppKit
import Foundation
import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Follow System"
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        }
    }

    var appAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .light:
            return NSAppearance(named: .aqua)
        }
    }
}

@MainActor
final class AppThemeManager: ObservableObject {
    static let shared = AppThemeManager()

    @Published private(set) var themeMode: AppThemeMode

    private let defaults = UserDefaults.standard

    private init() {
        let rawValue = defaults.string(forKey: AppPreferences.themeMode)
        themeMode = AppThemeMode(rawValue: rawValue ?? AppThemeMode.system.rawValue) ?? .system
    }

    var appAppearance: NSAppearance? {
        themeMode.appAppearance
    }

    func setThemeMode(_ mode: AppThemeMode) {
        guard themeMode != mode else { return }
        themeMode = mode
        defaults.set(mode.rawValue, forKey: AppPreferences.themeMode)
        applyAppearance()
    }

    func reloadFromDefaults() {
        let rawValue = defaults.string(forKey: AppPreferences.themeMode)
        themeMode = AppThemeMode(rawValue: rawValue ?? AppThemeMode.system.rawValue) ?? .system
        applyAppearance(postNotification: false)
    }

    func applyAppearance(postNotification: Bool = true) {
        NSApp.appearance = appAppearance
    }
}

enum AppThemePalette {
    static let windowBackground = dynamicColor(
        light: NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1),
        dark: NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)
    )
    static let sidebarBackground = dynamicColor(
        light: NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.95, alpha: 1),
        dark: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)
    )
    static let cardSurface = dynamicColor(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.78),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.05)
    )
    static let cardBorder = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.08),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.08)
    )
    static let controlSurface = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.05),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.08)
    )
    static let controlBorder = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.10),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.12)
    )
    static let segmentedBackground = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.06),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.06)
    )
    static let segmentedSelectedBackground = dynamicColor(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.92),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.10)
    )
    static let selectedSurface = dynamicColor(
        light: NSColor(calibratedRed: 0.16, green: 0.48, blue: 0.94, alpha: 0.12),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.10)
    )
    static let selectedBorder = dynamicColor(
        light: NSColor(calibratedRed: 0.16, green: 0.48, blue: 0.94, alpha: 0.22),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.16)
    )
    static let divider = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.08),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.08)
    )
    static let textPrimary = dynamicColor(
        light: NSColor(calibratedWhite: 0.10, alpha: 0.96),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.92)
    )
    static let textSecondary = dynamicColor(
        light: NSColor(calibratedWhite: 0.16, alpha: 0.74),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.72)
    )
    static let textTertiary = dynamicColor(
        light: NSColor(calibratedWhite: 0.20, alpha: 0.62),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.62)
    )
    static let textMuted = dynamicColor(
        light: NSColor(calibratedWhite: 0.22, alpha: 0.54),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.54)
    )
    static let textFaint = dynamicColor(
        light: NSColor(calibratedWhite: 0.25, alpha: 0.46),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.46)
    )
    static let panelShellStart = dynamicColor(
        light: NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.995, alpha: 1),
        dark: NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    )
    static let panelShellEnd = dynamicColor(
        light: NSColor(calibratedRed: 0.91, green: 0.94, blue: 0.99, alpha: 1),
        dark: NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.18, alpha: 1)
    )
    static let panelShellStroke = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.09),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.12)
    )
    static let panelShellHighlight = dynamicColor(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.42),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.14)
    )
    static let panelCardBackground = dynamicColor(
        light: NSColor(calibratedRed: 0.985, green: 0.99, blue: 0.995, alpha: 1),
        dark: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)
    )
    static let codeBlockBackground = dynamicColor(
        light: NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.98, alpha: 1),
        dark: NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1)
    )
    static let codeBlockBorder = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.06),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.06)
    )
    static let linkPreviewStart = dynamicColor(
        light: NSColor(calibratedRed: 0.82, green: 0.89, blue: 0.97, alpha: 1),
        dark: NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.23, alpha: 1)
    )
    static let linkPreviewEnd = dynamicColor(
        light: NSColor(calibratedRed: 0.72, green: 0.82, blue: 0.95, alpha: 1),
        dark: NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.16, alpha: 1)
    )
    static let contextMenuStart = dynamicColor(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.96),
        dark: NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.16, alpha: 0.97)
    )
    static let contextMenuEnd = dynamicColor(
        light: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 0.98),
        dark: NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 0.98)
    )
    static let checkerboardA = dynamicColor(
        light: NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.93, alpha: 1),
        dark: NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.14, alpha: 1)
    )
    static let checkerboardB = dynamicColor(
        light: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.97, alpha: 1),
        dark: NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)
    )
    static let iconFallbackBackground = dynamicColor(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.96),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.92)
    )
    static let selectionDot = dynamicColor(
        light: NSColor(calibratedWhite: 1.0, alpha: 0.96),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.92)
    )

    static var windowBackgroundNSColor: NSColor {
        nsColor(
            light: NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1),
            dark: NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)
        )
    }

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: nsColor(light: light, dark: dark))
    }

    private static func nsColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        }
    }
}
