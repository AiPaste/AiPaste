import Foundation

enum AppVersion {
    static var displayString: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let shortVersion, !shortVersion.isEmpty,
           let buildVersion, !buildVersion.isEmpty, buildVersion != shortVersion {
            return "\(shortVersion) (\(buildVersion))"
        }

        if let shortVersion, !shortVersion.isEmpty {
            return shortVersion
        }

        if let buildVersion, !buildVersion.isEmpty {
            return buildVersion
        }

        return "Unknown"
    }
}
