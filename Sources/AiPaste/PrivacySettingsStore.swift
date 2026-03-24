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
        showDuringScreenSharing = defaults.object(forKey: AppPreferences.showDuringScreenSharing) as? Bool ?? true
        generateLinkPreviews = defaults.object(forKey: AppPreferences.generateLinkPreviews) as? Bool ?? true
        ignoreConfidentialContent = defaults.object(forKey: AppPreferences.ignoreConfidentialContent) as? Bool ?? true
        ignoreTransientContent = defaults.object(forKey: AppPreferences.ignoreTransientContent) as? Bool ?? true

        if let data = defaults.data(forKey: AppPreferences.ignoredApplications),
           let decoded = try? decoder.decode([IgnoredApplication].self, from: data) {
            ignoredApplications = decoded
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

    func addIgnoredApplication(bundleIdentifier: String, name: String) {
        guard !bundleIdentifier.isEmpty else { return }
        guard !ignoredApplications.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else { return }
        ignoredApplications.append(IgnoredApplication(bundleIdentifier: bundleIdentifier, name: name))
        ignoredApplications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistIgnoredApplications()
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
}
