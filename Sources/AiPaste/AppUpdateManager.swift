import AppKit
import Foundation
import Sparkle

private enum SparkleKeys {
    static let automaticChecks = "SUEnableAutomaticChecks"
    static let feedURL = "SUFeedURL"
    static let publicEDKey = "SUPublicEDKey"
}

@MainActor
final class AppUpdateManager: NSObject, ObservableObject {
    static let shared = AppUpdateManager()

    @Published private(set) var automaticUpdatesEnabled: Bool
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var isChecking = false
    @Published private(set) var updateStatusMessage: String
    @Published private(set) var availableVersion: String?
    @Published private(set) var lastCheckedAt: Date?

    private let defaults = UserDefaults.standard
    private var updaterController: SPUStandardUpdaterController?
    private var hasAttemptedSetup = false
    private var canCheckObservation: NSKeyValueObservation?
    private var automaticChecksObservation: NSKeyValueObservation?

    private override init() {
        let automaticChecks = UserDefaults.standard.object(forKey: SparkleKeys.automaticChecks) as? Bool ?? true
        self.automaticUpdatesEnabled = automaticChecks
        self.updateStatusMessage = Self.unconfiguredStatusMessage(for: Bundle.main)
        super.init()
        reloadFromDefaults()
    }

    func configureOnLaunch() {
        _ = ensureUpdaterIsReady()
    }

    func reloadFromDefaults() {
        automaticUpdatesEnabled = defaults.object(forKey: SparkleKeys.automaticChecks) as? Bool ?? true
        if let updater = updaterController?.updater {
            automaticUpdatesEnabled = updater.automaticallyChecksForUpdates
            canCheckForUpdates = updater.canCheckForUpdates
            lastCheckedAt = updater.lastUpdateCheckDate
        } else {
            canCheckForUpdates = false
            lastCheckedAt = nil
        }
        refreshStatusMessage()
    }

    func checkForUpdates(userInitiated: Bool) async {
        guard userInitiated else {
            return
        }

        guard ensureUpdaterIsReady() else {
            presentConfigurationAlert()
            return
        }

        guard let updaterController else {
            presentConfigurationAlert()
            return
        }

        availableVersion = nil
        isChecking = true
        updateStatusMessage = "Checking for updates…"
        updaterController.checkForUpdates(nil)
    }

    func setAutomaticUpdates(_ enabled: Bool) {
        if ensureUpdaterIsReady(), let updater = updaterController?.updater {
            updater.automaticallyChecksForUpdates = enabled
            automaticUpdatesEnabled = updater.automaticallyChecksForUpdates
            canCheckForUpdates = updater.canCheckForUpdates
        } else {
            automaticUpdatesEnabled = enabled
            defaults.set(enabled, forKey: SparkleKeys.automaticChecks)
        }

        refreshStatusMessage()
    }

    private func ensureUpdaterIsReady() -> Bool {
        if let updaterController {
            automaticUpdatesEnabled = updaterController.updater.automaticallyChecksForUpdates
            canCheckForUpdates = updaterController.updater.canCheckForUpdates
            return true
        }

        guard !hasAttemptedSetup else {
            return false
        }

        hasAttemptedSetup = true

        guard Bundle.main.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              Bundle.main.bundleURL.pathExtension == "app" else {
            updateStatusMessage = Self.unconfiguredStatusMessage(for: Bundle.main)
            return false
        }

        guard let feedURL = Bundle.main.object(forInfoDictionaryKey: SparkleKeys.feedURL) as? String,
              !feedURL.isEmpty,
              let publicKey = Bundle.main.object(forInfoDictionaryKey: SparkleKeys.publicEDKey) as? String,
              !publicKey.isEmpty else {
            updateStatusMessage = "Sparkle feed is not configured in this build"
            return false
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        updaterController = controller
        installObservers(for: controller.updater)
        controller.startUpdater()
        automaticUpdatesEnabled = controller.updater.automaticallyChecksForUpdates
        canCheckForUpdates = controller.updater.canCheckForUpdates
        updateStatusMessage = "Automatic updates enabled"
        return true
    }

    private func installObservers(for updater: SPUUpdater) {
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.canCheckForUpdates = updater.canCheckForUpdates
                self.refreshStatusMessage()
            }
        }

        automaticChecksObservation = updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.automaticUpdatesEnabled = updater.automaticallyChecksForUpdates
                self.refreshStatusMessage()
            }
        }
    }

    private func refreshStatusMessage() {
        if let version = availableVersion {
            updateStatusMessage = "Version \(version) available"
            return
        }

        if isChecking {
            updateStatusMessage = "Checking for updates…"
            return
        }

        if updaterController == nil {
            updateStatusMessage = Self.unconfiguredStatusMessage(for: Bundle.main)
            return
        }

        if let lastCheckedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            updateStatusMessage = "Last checked \(formatter.localizedString(for: lastCheckedAt, relativeTo: .now))"
        } else if automaticUpdatesEnabled {
            updateStatusMessage = "Automatic updates enabled"
        } else {
            updateStatusMessage = "Automatic update checks are off"
        }
    }

    private func presentConfigurationAlert() {
        let alert = NSAlert()
        alert.messageText = "Software Update Unavailable"
        alert.informativeText = updateStatusMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func unconfiguredStatusMessage(for bundle: Bundle) -> String {
        guard bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              bundle.bundleURL.pathExtension == "app" else {
            return "Software updates are available in packaged app builds"
        }
        return "Sparkle feed is not configured in this build"
    }
}

extension AppUpdateManager: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        availableVersion = normalizedVersion(item.displayVersionString)
        isChecking = false
        refreshStatusMessage()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        availableVersion = nil
        isChecking = false
        lastCheckedAt = updater.lastUpdateCheckDate
        updateStatusMessage = "Up to date"
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        availableVersion = normalizedVersion(item.displayVersionString)
        updateStatusMessage = "Version \(availableVersion ?? item.displayVersionString) ready to install"
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        availableVersion = normalizedVersion(item.displayVersionString)
        updateStatusMessage = "Installing version \(availableVersion ?? item.displayVersionString)…"
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        updateStatusMessage = "Restarting to finish update…"
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        isChecking = false
        availableVersion = nil
        updateStatusMessage = "Update failed"
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        isChecking = false
        lastCheckedAt = updater.lastUpdateCheckDate
    }

    private func normalizedVersion(_ value: String) -> String {
        value.hasPrefix("v") ? String(value.dropFirst()) : value
    }
}
