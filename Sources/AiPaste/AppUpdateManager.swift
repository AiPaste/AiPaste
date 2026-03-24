import AppKit
import Foundation

@MainActor
final class AppUpdateManager: ObservableObject {
    static let shared = AppUpdateManager()

    @Published private(set) var automaticUpdatesEnabled: Bool
    @Published private(set) var isChecking = false
    @Published private(set) var updateStatusMessage = "Not checked yet"
    @Published private(set) var availableVersion: String?
    @Published private(set) var lastCheckedAt: Date?

    private let defaults = UserDefaults.standard
    private let session: URLSession
    private let releasesURL = URL(string: "https://api.github.com/repos/AiPaste/AiPaste/releases/latest")!
    private let minimumCheckInterval: TimeInterval = 60 * 60 * 12

    private init(session: URLSession = .shared) {
        self.session = session
        automaticUpdatesEnabled = true
        reloadFromDefaults()
    }

    func configureOnLaunch() {
        guard automaticUpdatesEnabled else { return }
        guard shouldCheckAutomatically else { return }
        Task {
            await checkForUpdates(userInitiated: false)
        }
    }

    func setAutomaticUpdates(_ enabled: Bool) {
        automaticUpdatesEnabled = enabled
        defaults.set(enabled, forKey: AppPreferences.automaticUpdates)
        if enabled {
            Task {
                await checkForUpdates(userInitiated: false)
            }
        }
    }

    func reloadFromDefaults() {
        automaticUpdatesEnabled = defaults.object(forKey: AppPreferences.automaticUpdates) as? Bool ?? true
        lastCheckedAt = defaults.object(forKey: AppPreferences.lastUpdateCheck) as? Date

        if let availableVersion {
            updateStatusMessage = "Version \(availableVersion) available"
        } else if let lastCheckedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            updateStatusMessage = "Last checked \(formatter.localizedString(for: lastCheckedAt, relativeTo: .now))"
        } else {
            updateStatusMessage = "Not checked yet"
        }
    }

    func checkForUpdates(userInitiated: Bool) async {
        guard !isChecking else { return }

        isChecking = true
        defer { isChecking = false }

        if userInitiated {
            updateStatusMessage = "Checking for updates…"
        }

        do {
            var request = URLRequest(url: releasesURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("AiPaste", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw AppUpdateError.invalidResponse
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            handleReleaseResponse(release, userInitiated: userInitiated)
        } catch {
            let message = "Update check failed"
            updateStatusMessage = message
            if userInitiated {
                presentErrorAlert(message: message, error: error)
            }
        }
    }

    func openLatestReleaseDownload() {
        guard let releaseURL = latestDownloadURL else { return }
        NSWorkspace.shared.open(releaseURL)
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(URL(string: "https://github.com/AiPaste/AiPaste/releases")!)
    }

    private var shouldCheckAutomatically: Bool {
        guard let lastCheckedAt else { return true }
        return Date().timeIntervalSince(lastCheckedAt) >= minimumCheckInterval
    }

    private var latestDownloadURL: URL?

    private func handleReleaseResponse(_ release: GitHubRelease, userInitiated: Bool) {
        let latestVersion = normalizedVersion(from: release.tagName)
        lastCheckedAt = Date()
        defaults.set(lastCheckedAt, forKey: AppPreferences.lastUpdateCheck)

        guard let currentVersion = currentVersionString else {
            updateStatusMessage = "Update check available in packaged app builds"
            availableVersion = latestVersion
            return
        }

        if version(latestVersion, isNewerThan: currentVersion) {
            availableVersion = latestVersion
            latestDownloadURL = release.assets.first(where: { $0.name.hasSuffix("-macOS.zip") })?.browserDownloadURL ?? release.htmlURL
            updateStatusMessage = "Version \(latestVersion) available"
            presentUpdateAlert(version: latestVersion, release: release, userInitiated: userInitiated)
        } else {
            availableVersion = nil
            latestDownloadURL = nil
            updateStatusMessage = "Up to date"
            if userInitiated {
                presentUpToDateAlert(version: currentVersion)
            }
        }
    }

    private func presentUpdateAlert(version: String, release: GitHubRelease, userInitiated: Bool) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "AiPaste \(version) is available. You are currently using \(currentVersionString ?? "an older version")."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            let targetURL = release.assets.first(where: { $0.name.hasSuffix("-macOS.zip") })?.browserDownloadURL ?? release.htmlURL
            latestDownloadURL = targetURL
            NSWorkspace.shared.open(targetURL)
        } else if userInitiated {
            updateStatusMessage = "Version \(version) available"
        }
    }

    private func presentUpToDateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = "You’re Up to Date"
        alert.informativeText = "AiPaste \(version) is the latest available version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentErrorAlert(message: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private var currentVersionString: String? {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else {
            return nil
        }
        return normalizedVersion(from: version)
    }

    private func normalizedVersion(from rawValue: String) -> String {
        rawValue.hasPrefix("v") ? String(rawValue.dropFirst()) : rawValue
    }

    private func version(_ lhs: String, isNewerThan rhs: String) -> Bool {
        let lhsParts = lhs.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        let rhsParts = rhs.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left != right {
                return left > right
            }
        }

        return lhs != rhs && lhs.compare(rhs, options: .numeric) == .orderedDescending
    }
}

private enum AppUpdateError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The update server returned an unexpected response."
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
