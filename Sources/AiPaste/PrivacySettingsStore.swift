import AppKit
import Foundation

struct IgnoredApplication: Codable, Identifiable, Hashable {
    let bundleIdentifier: String
    var name: String

    var id: String { bundleIdentifier }
}

@MainActor
final class PrivacySettingsStore: ObservableObject {
    static let shared = PrivacySettingsStore()

    @Published private(set) var showDuringScreenSharing: Bool
    @Published private(set) var generateLinkPreviews: Bool
    @Published private(set) var ignoreConfidentialContent: Bool
    @Published private(set) var ignoreTransientContent: Bool
    @Published private(set) var ignoredApplications: [IgnoredApplication]

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        showDuringScreenSharing = true
        generateLinkPreviews = true
        ignoreConfidentialContent = true
        ignoreTransientContent = true
        ignoredApplications = []
        reloadFromDefaults()
    }

    func reloadFromDefaults() {
        showDuringScreenSharing = defaults.object(forKey: AppPreferences.showDuringScreenSharing) as? Bool ?? true
        generateLinkPreviews = defaults.object(forKey: AppPreferences.generateLinkPreviews) as? Bool ?? true
        ignoreConfidentialContent = defaults.object(forKey: AppPreferences.ignoreConfidentialContent) as? Bool ?? true
        ignoreTransientContent = defaults.object(forKey: AppPreferences.ignoreTransientContent) as? Bool ?? true

        if let data = defaults.data(forKey: AppPreferences.ignoredApplications),
           let decoded = try? decoder.decode([IgnoredApplication].self, from: data) {
            ignoredApplications = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            ignoredApplications = []
        }
    }

    func setShowDuringScreenSharing(_ value: Bool) {
        showDuringScreenSharing = value
        defaults.set(value, forKey: AppPreferences.showDuringScreenSharing)
        AppState.shared.applyWindowPrivacySettings()
    }

    func setGenerateLinkPreviews(_ value: Bool) {
        generateLinkPreviews = value
        defaults.set(value, forKey: AppPreferences.generateLinkPreviews)
    }

    func setIgnoreConfidentialContent(_ value: Bool) {
        ignoreConfidentialContent = value
        defaults.set(value, forKey: AppPreferences.ignoreConfidentialContent)
    }

    func setIgnoreTransientContent(_ value: Bool) {
        ignoreTransientContent = value
        defaults.set(value, forKey: AppPreferences.ignoreTransientContent)
    }

    @discardableResult
    func addIgnoredApplication(bundleIdentifier: String, name: String) -> IgnoredApplication? {
        guard !bundleIdentifier.isEmpty else { return nil }
        if let existingApplication = ignoredApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return existingApplication
        }

        let ignoredApplication = IgnoredApplication(bundleIdentifier: bundleIdentifier, name: name)
        ignoredApplications.append(ignoredApplication)
        ignoredApplications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistIgnoredApplications()
        return ignoredApplication
    }

    @discardableResult
    func chooseAndAddIgnoredApplication() -> IgnoredApplication? {
        let panel = NSOpenPanel()
        panel.title = "Choose Application to Ignore"
        panel.prompt = "Ignore"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = preferredApplicationsDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return addIgnoredApplication(from: url)
    }

    @discardableResult
    func addIgnoredApplication(from appURL: URL) -> IgnoredApplication? {
        let bundle = Bundle(url: appURL)
        let bundleIdentifier = bundle?.bundleIdentifier
            ?? Bundle(path: appURL.path)?.bundleIdentifier
            ?? inferredBundleIdentifier(from: appURL)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        guard let bundleIdentifier else { return nil }
        return addIgnoredApplication(bundleIdentifier: bundleIdentifier, name: displayName)
    }

    func removeIgnoredApplication(bundleIdentifier: String) {
        ignoredApplications.removeAll { $0.bundleIdentifier == bundleIdentifier }
        persistIgnoredApplications()
    }

    func isIgnored(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return ignoredApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    var availableApplicationsToIgnore: [IgnoredApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0 != NSRunningApplication.current }
            .compactMap { application in
                guard let bundleIdentifier = application.bundleIdentifier,
                      let name = application.localizedName,
                      application.activationPolicy == .regular else { return nil }
                return IgnoredApplication(bundleIdentifier: bundleIdentifier, name: name)
            }
            .filter { candidate in
                !ignoredApplications.contains(where: { $0.bundleIdentifier == candidate.bundleIdentifier })
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func appIcon(for application: IgnoredApplication) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.bundleIdentifier) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 28, height: 28)
        return icon
    }

    private func persistIgnoredApplications() {
        if let data = try? encoder.encode(ignoredApplications) {
            defaults.set(data, forKey: AppPreferences.ignoredApplications)
        }
    }

    private func inferredBundleIdentifier(from appURL: URL) -> String? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String else {
            return nil
        }
        return bundleIdentifier
    }

    private var preferredApplicationsDirectoryURL: URL? {
        let fileManager = FileManager.default
        let primaryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if fileManager.fileExists(atPath: primaryURL.path) {
            return primaryURL
        }

        let userApplicationsURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
        if fileManager.fileExists(atPath: userApplicationsURL.path) {
            return userApplicationsURL
        }

        return nil
    }
}
