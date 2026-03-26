import Foundation

enum PasteDestinationMode: String {
    case activeApp
    case clipboard
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case privacy
    case shortcuts
    case subscription

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .privacy:
            return "Privacy"
        case .shortcuts:
            return "Shortcuts"
        case .subscription:
            return "Subscription"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .privacy:
            return "hand.raised"
        case .shortcuts:
            return "keyboard"
        case .subscription:
            return "checkmark.seal"
        }
    }
}

enum HistoryRetention: Int, CaseIterable, Identifiable {
    case day = 0
    case week = 1
    case month = 2
    case year = 3
    case forever = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .year:
            return "Year"
        case .forever:
            return "Forever"
        }
    }

    var maxAge: TimeInterval? {
        switch self {
        case .day:
            return 60 * 60 * 24
        case .week:
            return 60 * 60 * 24 * 7
        case .month:
            return 60 * 60 * 24 * 30
        case .year:
            return 60 * 60 * 24 * 365
        case .forever:
            return nil
        }
    }
}

enum AppPreferences {
    static let openAtLogin = "settings.openAtLogin"
    static let runInBackground = "settings.runInBackground"
    static let themeMode = "settings.themeMode"
    static let iCloudSync = "settings.iCloudSync"
    static let soundEffects = "settings.soundEffects"
    static let showDuringScreenSharing = "settings.showDuringScreenSharing"
    static let generateLinkPreviews = "settings.generateLinkPreviews"
    static let ignoreConfidentialContent = "settings.ignoreConfidentialContent"
    static let ignoreTransientContent = "settings.ignoreTransientContent"
    static let ignoredApplications = "settings.ignoredApplications"
    static let pasteDestination = "settings.pasteDestination"
    static let alwaysPastePlainText = "settings.alwaysPastePlainText"
    static let historyRetention = "settings.historyRetention"
}
