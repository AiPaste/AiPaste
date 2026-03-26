import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation
import ServiceManagement

enum AppCLI {
    static func isCLIInvocation(_ arguments: [String] = CommandLine.arguments) -> Bool {
        Array(arguments.dropFirst()).first == "cli"
    }

    @MainActor
    static func run(_ arguments: [String] = CommandLine.arguments) -> Int32 {
        let cliArguments = Array(arguments.dropFirst(2))
        let runner = CLIRunner(arguments: cliArguments)
        return runner.run()
    }
}

@MainActor
private final class CLIRunner {
    private var arguments: [String]
    private let store = ClipboardStore(enableMonitoring: false)
    private let privacyStore = PrivacySettingsStore.shared
    private let defaults = UserDefaults.standard

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func run() -> Int32 {
        do {
            if arguments.isEmpty || arguments.first == "help" || arguments.first == "--help" || arguments.first == "-h" {
                printLine(Self.usage)
                return 0
            }

            let command = try popArgument()
            switch command {
            case "panel":
                try handlePanel()
            case "settings":
                try handleSettings()
            case "capture":
                AppCommandBridge.post(.captureClipboard)
                printLine("Requested clipboard capture.")
            case "list":
                try handleList()
            case "items":
                try handleItems()
            case "groups":
                try handleGroups()
            case "ignore":
                try handleIgnore()
            case "config":
                try handleConfig()
            default:
                throw CLIError("Unknown command: \(command)")
            }

            return 0
        } catch let error as CLIError {
            printError(error.message)
            return 1
        } catch {
            printError(error.localizedDescription)
            return 1
        }
    }

    private func handlePanel() throws {
        let action = try popArgument()
        let command: AppBridgeCommand

        switch action {
        case "show":
            command = .showPanel
        case "hide":
            command = .hidePanel
        case "toggle":
            command = .togglePanel
        default:
            throw CLIError("Unknown panel action: \(action)")
        }

        AppCommandBridge.post(command)
        printLine("Requested panel \(action).")
    }

    private func handleSettings() throws {
        let action = arguments.first ?? "open"
        guard action == "open" else {
            throw CLIError("Unknown settings action: \(action)")
        }
        if !arguments.isEmpty {
            _ = try popArgument()
        }
        AppCommandBridge.post(.openSettings)
        printLine("Requested settings window.")
    }

    private func handleList() throws {
        var groupSelector: String?
        var searchText = ""
        var json = false
        var limit: Int?

        while let option = arguments.first {
            switch option {
            case "--group":
                _ = try popArgument()
                groupSelector = try popArgument()
            case "--search":
                _ = try popArgument()
                searchText = try popArgument()
            case "--limit":
                _ = try popArgument()
                limit = Int(try popArgument())
            case "--json":
                _ = try popArgument()
                json = true
            default:
                throw CLIError("Unknown list option: \(option)")
            }
        }

        applyQuery(groupSelector: groupSelector, searchText: searchText)
        var items = store.visibleItems
        if let limit, limit > 0 {
            items = Array(items.prefix(limit))
        }

        if json {
            let payload = items.enumerated().map { index, item in
                ItemSummary(index: index + 1, item: item, group: store.group(for: item.groupID))
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            guard let string = String(data: data, encoding: .utf8) else {
                throw CLIError("Failed to encode JSON output.")
            }
            printLine(string)
            return
        }

        if items.isEmpty {
            printLine("No items found.")
            return
        }

        for (index, item) in items.enumerated() {
            let groupName = store.group(for: item.groupID)?.title ?? "Clipboard"
            let summary: String
            switch item.kind {
            case .image:
                summary = item.imageSize?.label ?? "Image"
            case .pdf:
                summary = item.pdfFileName ?? item.footerLabel
            case .text, .code, .link:
                summary = item.textPreview.replacingOccurrences(of: "\n", with: " ")
            }
            printLine("[\(index + 1)] \(item.id.uuidString) \(item.cardTitle) \(groupName) \(summary)")
        }
    }

    private func handleItems() throws {
        let action = try popArgument()
        switch action {
        case "copy":
            let item = try resolveItem(try popArgument())
            store.copy(item)
            AppCommandBridge.post(.reloadStore)
            printLine("Copied item \(item.id.uuidString) to the clipboard.")
        case "paste":
            let item = try resolveItem(try popArgument())
            try paste(item)
            AppCommandBridge.post(.reloadStore)
        case "pin":
            let item = try resolveItem(try popArgument())
            if !item.isPinned {
                store.togglePin(item)
                AppCommandBridge.post(.reloadStore)
            }
            printLine("Pinned item \(item.id.uuidString).")
        case "unpin":
            let item = try resolveItem(try popArgument())
            if item.isPinned {
                store.togglePin(item)
                AppCommandBridge.post(.reloadStore)
            }
            printLine("Unpinned item \(item.id.uuidString).")
        case "delete":
            let item = try resolveItem(try popArgument())
            store.remove(item)
            AppCommandBridge.post(.reloadStore)
            printLine("Deleted item \(item.id.uuidString).")
        case "move":
            let item = try resolveItem(try popArgument())
            let destination = try popArgument()
            let groupID = try resolveGroupIdentifier(destination)
            store.move(item, toGroupID: groupID)
            AppCommandBridge.post(.reloadStore)
            printLine("Moved item \(item.id.uuidString) to \(destination).")
        default:
            throw CLIError("Unknown items action: \(action)")
        }
    }

    private func handleGroups() throws {
        let action = try popArgument()
        switch action {
        case "list":
            if store.groups.isEmpty {
                printLine("No groups found.")
            } else {
                for group in store.groups {
                    printLine("\(group.id) \(group.title) \(group.colorToken.rawValue)")
                }
            }
        case "create":
            let customName = arguments.first
            store.createGroup()
            guard let createdGroup = store.groups.last else {
                throw CLIError("Failed to create group.")
            }
            if let customName, !customName.isEmpty {
                store.renameGroup(id: createdGroup.id, to: customName)
                _ = try? popArgument()
            }
            AppCommandBridge.post(.reloadStore)
            let latestGroup = store.group(for: createdGroup.id) ?? createdGroup
            printLine("Created group \(latestGroup.id) \(latestGroup.title).")
        case "rename":
            let group = try resolveGroup(try popArgument())
            let newName = try popArgument()
            store.renameGroup(id: group.id, to: newName)
            AppCommandBridge.post(.reloadStore)
            printLine("Renamed group \(group.id) to \(newName).")
        case "delete":
            let group = try resolveGroup(try popArgument())
            store.deleteGroup(id: group.id)
            AppCommandBridge.post(.reloadStore)
            printLine("Deleted group \(group.id).")
        case "color":
            let group = try resolveGroup(try popArgument())
            let rawColor = try popArgument().lowercased()
            guard let token = GroupColorToken(rawValue: rawColor) else {
                throw CLIError("Unsupported color: \(rawColor)")
            }
            store.updateGroupColor(id: group.id, token: token)
            AppCommandBridge.post(.reloadStore)
            printLine("Updated group \(group.id) color to \(token.rawValue).")
        default:
            throw CLIError("Unknown groups action: \(action)")
        }
    }

    private func handleIgnore() throws {
        let action = try popArgument()
        switch action {
        case "list":
            if privacyStore.ignoredApplications.isEmpty {
                printLine("No ignored applications configured.")
            } else {
                for application in privacyStore.ignoredApplications {
                    printLine("\(application.bundleIdentifier) \(application.name)")
                }
            }
        case "add":
            if arguments.first == "--app" {
                _ = try popArgument()
                let appPath = try popArgument()
                guard let application = privacyStore.addIgnoredApplication(from: URL(fileURLWithPath: appPath)) else {
                    throw CLIError("Failed to add ignored application from path: \(appPath)")
                }
                printLine("Ignored \(application.name).")
            } else if arguments.first == "--bundle-id" {
                _ = try popArgument()
                let bundleIdentifier = try popArgument()
                let name = arguments.first == "--name" ? {
                    _ = try? popArgument()
                    return (try? popArgument()) ?? bundleIdentifier
                }() : bundleIdentifier
                guard let application = privacyStore.addIgnoredApplication(bundleIdentifier: bundleIdentifier, name: name) else {
                    throw CLIError("Failed to add ignored application: \(bundleIdentifier)")
                }
                printLine("Ignored \(application.name).")
            } else {
                throw CLIError("Use `ignore add --app /Applications/Foo.app` or `ignore add --bundle-id com.example.foo [--name Foo]`.")
            }
        case "remove":
            let bundleIdentifier = try popArgument()
            privacyStore.removeIgnoredApplication(bundleIdentifier: bundleIdentifier)
            printLine("Removed ignored application \(bundleIdentifier).")
        default:
            throw CLIError("Unknown ignore action: \(action)")
        }

        AppCommandBridge.post(.refreshSettings)
    }

    private func handleConfig() throws {
        let action = try popArgument()
        switch action {
        case "list":
            for key in ConfigurationKey.allCases {
                printLine("\(key.rawValue)=\(currentValue(for: key))")
            }
        case "get":
            let key = try resolveConfigurationKey(try popArgument())
            printLine(currentValue(for: key))
        case "set":
            let key = try resolveConfigurationKey(try popArgument())
            let value = try popArgument()
            try updateConfiguration(key: key, value: value)
            printLine("\(key.rawValue)=\(currentValue(for: key))")
        default:
            throw CLIError("Unknown config action: \(action)")
        }
    }

    private func applyQuery(groupSelector: String?, searchText: String) {
        store.reloadFromDisk()
        store.searchText = searchText

        if let groupSelector {
            if groupSelector == "all" || groupSelector == "clipboard" {
                store.selectedSourceID = "all"
            } else if let group = store.groups.first(where: { $0.id == groupSelector || $0.title == groupSelector }) {
                store.selectedSourceID = group.id
            } else {
                store.selectedSourceID = "all"
            }
        } else {
            store.selectedSourceID = "all"
        }
    }

    private func resolveItem(_ specifier: String) throws -> ClipboardItem {
        store.reloadFromDisk()
        let items = store.visibleItems

        if let uuid = UUID(uuidString: specifier),
           let item = items.first(where: { $0.id == uuid }) ?? store.items.first(where: { $0.id == uuid }) {
            return item
        }

        if let index = Int(specifier), index > 0, index <= items.count {
            return items[index - 1]
        }

        throw CLIError("Unable to find item: \(specifier)")
    }

    private func resolveGroup(_ specifier: String) throws -> ClipboardGroup {
        store.reloadFromDisk()
        if let group = store.groups.first(where: { $0.id == specifier || $0.title == specifier }) {
            return group
        }
        throw CLIError("Unable to find group: \(specifier)")
    }

    private func resolveGroupIdentifier(_ specifier: String) throws -> String? {
        if specifier == "clipboard" || specifier == "all" {
            return nil
        }
        return try resolveGroup(specifier).id
    }

    private func paste(_ item: ClipboardItem) throws {
        let copyResult = store.copy(item)
        guard copyResult.success else {
            throw CLIError("Failed to copy item \(item.id.uuidString) to the clipboard.")
        }
        let destination = PasteDestinationMode(rawValue: defaults.string(forKey: AppPreferences.pasteDestination) ?? PasteDestinationMode.activeApp.rawValue) ?? .activeApp

        guard destination == .activeApp else {
            printLine("Copied item \(item.id.uuidString) to the clipboard.")
            return
        }

        guard AXIsProcessTrusted() else {
            throw CLIError("Accessibility permission is required to paste into the active app. Enable it in System Settings > Privacy & Security > Accessibility.")
        }

        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw CLIError("Failed to create keyboard event source.")
        }

        guard let targetApplication = NSWorkspace.shared.frontmostApplication else {
            throw CLIError("No active application available to receive paste.")
        }

        let usesPlainText = (defaults.object(forKey: AppPreferences.alwaysPastePlainText) as? Bool ?? false)
            && (item.kind == .text || item.kind == .code || item.kind == .link)
        let flags: CGEventFlags = usesPlainText ? [.maskCommand, .maskAlternate, .maskShift] : .maskCommand
        let keyCode = CGKeyCode(kVK_ANSI_V)

        targetApplication.activate()
        _ = FrontmostApplicationWaiter.waitBlocking(
            for: targetApplication,
            timeout: copyResult.activationTimeout
        )

        let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        printLine("Pasted item \(item.id.uuidString) into \(targetApplication.localizedName ?? "active app").")
    }

    private func resolveConfigurationKey(_ rawValue: String) throws -> ConfigurationKey {
        guard let key = ConfigurationKey(rawValue: rawValue) else {
            throw CLIError("Unknown config key: \(rawValue)")
        }
        return key
    }

    private func currentValue(for key: ConfigurationKey) -> String {
        switch key {
        case .openAtLogin:
            let status = SMAppService.mainApp.status
            return (status == .enabled || status == .requiresApproval) ? "true" : "false"
        case .runInBackground:
            return boolString(defaults.object(forKey: AppPreferences.runInBackground) as? Bool ?? true)
        case .automaticUpdates:
            return boolString(AppUpdateManager.shared.automaticUpdatesEnabled)
        case .iCloudSync:
            return boolString(store.iCloudSyncEnabled)
        case .soundEffects:
            return boolString(defaults.object(forKey: AppPreferences.soundEffects) as? Bool ?? true)
        case .showDuringScreenSharing:
            return boolString(privacyStore.showDuringScreenSharing)
        case .generateLinkPreviews:
            return boolString(privacyStore.generateLinkPreviews)
        case .ignoreConfidentialContent:
            return boolString(privacyStore.ignoreConfidentialContent)
        case .ignoreTransientContent:
            return boolString(privacyStore.ignoreTransientContent)
        case .pasteDestination:
            return defaults.string(forKey: AppPreferences.pasteDestination) ?? PasteDestinationMode.activeApp.rawValue
        case .alwaysPastePlainText:
            return boolString(defaults.object(forKey: AppPreferences.alwaysPastePlainText) as? Bool ?? false)
        case .historyRetention:
            let rawValue = defaults.object(forKey: AppPreferences.historyRetention) as? Int ?? HistoryRetention.month.rawValue
            return HistoryRetention(rawValue: rawValue)?.title.lowercased() ?? "month"
        }
    }

    private func updateConfiguration(key: ConfigurationKey, value: String) throws {
        switch key {
        case .openAtLogin:
            let enabled = try parseBool(value)
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                throw CLIError("Failed to update open-at-login: \(error.localizedDescription)")
            }
        case .runInBackground:
            defaults.set(try parseBool(value), forKey: AppPreferences.runInBackground)
        case .automaticUpdates:
            AppUpdateManager.shared.setAutomaticUpdates(try parseBool(value))
        case .iCloudSync:
            store.setICloudSync(try parseBool(value))
        case .soundEffects:
            defaults.set(try parseBool(value), forKey: AppPreferences.soundEffects)
        case .showDuringScreenSharing:
            privacyStore.setShowDuringScreenSharing(try parseBool(value))
        case .generateLinkPreviews:
            privacyStore.setGenerateLinkPreviews(try parseBool(value))
        case .ignoreConfidentialContent:
            privacyStore.setIgnoreConfidentialContent(try parseBool(value))
        case .ignoreTransientContent:
            privacyStore.setIgnoreTransientContent(try parseBool(value))
        case .pasteDestination:
            let normalized = value.lowercased()
            guard normalized == PasteDestinationMode.activeApp.rawValue || normalized == PasteDestinationMode.clipboard.rawValue else {
                throw CLIError("paste-destination must be `activeApp` or `clipboard`.")
            }
            defaults.set(normalized, forKey: AppPreferences.pasteDestination)
        case .alwaysPastePlainText:
            defaults.set(try parseBool(value), forKey: AppPreferences.alwaysPastePlainText)
        case .historyRetention:
            guard let retention = historyRetention(from: value) else {
                throw CLIError("history-retention must be day, week, month, year, or forever.")
            }
            store.setHistoryRetention(retention)
        }

        AppCommandBridge.post(.refreshSettings)
        AppCommandBridge.post(.reloadStore)
    }

    private func historyRetention(from rawValue: String) -> HistoryRetention? {
        switch rawValue.lowercased() {
        case "day":
            return .day
        case "week":
            return .week
        case "month":
            return .month
        case "year":
            return .year
        case "forever":
            return .forever
        default:
            return nil
        }
    }

    private func parseBool(_ rawValue: String) throws -> Bool {
        switch rawValue.lowercased() {
        case "true", "1", "yes", "on":
            return true
        case "false", "0", "no", "off":
            return false
        default:
            throw CLIError("Expected a boolean value, got: \(rawValue)")
        }
    }

    private func boolString(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private func popArgument() throws -> String {
        guard !arguments.isEmpty else {
            throw CLIError("Missing required argument.")
        }
        return arguments.removeFirst()
    }

    private func printLine(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }

    private func printError(_ text: String) {
        FileHandle.standardError.write(Data(("Error: " + text + "\n").utf8))
    }

    private static let usage = """
    AiPaste CLI

    Usage:
      aipaste panel show|hide|toggle
      aipaste settings open
      aipaste capture
      aipaste list [--group <group-id|group-title|clipboard|all>] [--search <text>] [--limit N] [--json]
      aipaste items copy|paste|pin|unpin|delete <item-id|index>
      aipaste items move <item-id|index> <group-id|group-title|clipboard>
      aipaste groups list
      aipaste groups create [name]
      aipaste groups rename <group-id|group-title> <new-name>
      aipaste groups delete <group-id|group-title>
      aipaste groups color <group-id|group-title> <red|orange|yellow|gray|green|blue|purple|pink>
      aipaste ignore list
      aipaste ignore add --app /Applications/Foo.app
      aipaste ignore add --bundle-id com.example.foo [--name "Foo"]
      aipaste ignore remove <bundle-id>
      aipaste config list
      aipaste config get <key>
      aipaste config set <key> <value>
    """
}

private struct CLIError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

private struct ItemSummary: Encodable {
    let index: Int
    let id: UUID
    let kind: String
    let groupID: String?
    let groupTitle: String?
    let appName: String
    let bundleIdentifier: String?
    let codeLanguage: String?
    let sourceFileName: String?
    let pinned: Bool
    let capturedAt: Date
    let preview: String

    init(index: Int, item: ClipboardItem, group: ClipboardGroup?) {
        self.index = index
        id = item.id
        kind = item.kind.rawValue
        groupID = item.groupID
        groupTitle = group?.title
        appName = item.appName
        bundleIdentifier = item.bundleIdentifier
        codeLanguage = item.codeLanguage
        sourceFileName = item.sourceFileName
        pinned = item.isPinned
        capturedAt = item.capturedAt
        switch item.kind {
        case .image:
            preview = item.imageSize?.label ?? "Image"
        case .pdf:
            preview = item.pdfFileName ?? item.footerLabel
        case .text, .code, .link:
            preview = item.textPreview
        }
    }
}

private enum ConfigurationKey: String, CaseIterable {
    case openAtLogin = "open-at-login"
    case runInBackground = "run-in-background"
    case automaticUpdates = "automatic-updates"
    case iCloudSync = "icloud-sync"
    case soundEffects = "sound-effects"
    case showDuringScreenSharing = "show-during-screen-sharing"
    case generateLinkPreviews = "generate-link-previews"
    case ignoreConfidentialContent = "ignore-confidential-content"
    case ignoreTransientContent = "ignore-transient-content"
    case pasteDestination = "paste-destination"
    case alwaysPastePlainText = "always-paste-plain-text"
    case historyRetention = "history-retention"
}
