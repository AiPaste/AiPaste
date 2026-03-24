import AppKit
import ApplicationServices
import Carbon
import Foundation
import OSLog
import ServiceManagement

private enum PasteShortcutMode {
    case regular
    case plainText
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let store = ClipboardStore()
    let shortcutManager = AppShortcutManager.shared
    @Published private(set) var isPanelVisible = false
    @Published private(set) var pasteAutomationAvailable = AXIsProcessTrusted()
    @Published var openAtLoginEnabled = false
    @Published var runInBackgroundEnabled = true
    @Published var selectedItemID: UUID?

    private let logger = Logger(subsystem: "AiPaste", category: "AppState")
    private var lastTargetApplication: NSRunningApplication?

    private lazy var panelController = ClipboardPanelController(
        store: store,
        onVisibilityChange: { [weak self] isVisible in
            self?.isPanelVisible = isVisible
            if !isVisible {
                self?.evaluateBackgroundPolicy()
            }
        },
        onNavigationCommand: { [weak self] command in
            self?.handlePanelNavigation(command)
        },
        onConfirmSelection: { [weak self] in
            self?.pasteSelectedItem()
        },
        onOpenSettings: { [weak self] in
            self?.openSettings(hidePanel: true)
        }
    )
    private lazy var hotKeyManager = GlobalHotKeyManager {
        Task { @MainActor in
            AppState.shared.showPanel()
        }
    }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShortcutsDidChange),
            name: .aiPasteShortcutsDidChange,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleBridgeCommand(_:)),
            name: AppCommandBridge.commandNotification,
            object: nil
        )
    }

    func start() {
        pasteAutomationAvailable = ensureAccessibilityPermission(prompt: false)
        refreshOpenAtLoginStatus()
        runInBackgroundEnabled = UserDefaults.standard.object(forKey: AppPreferences.runInBackground) as? Bool ?? true
        registerGlobalShortcuts()
    }

    func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           frontmostApplication != NSRunningApplication.current {
            lastTargetApplication = frontmostApplication
            logger.debug("showPanel captured frontmost app: \(frontmostApplication.localizedName ?? "unknown", privacy: .public) [\(frontmostApplication.bundleIdentifier ?? "nil", privacy: .public)]")
        } else {
            logger.debug("showPanel did not capture external frontmost app")
        }
        panelController.show()
        syncSelectionToVisibleItems(preferFirst: true)
    }

    func hidePanel() {
        panelController.hide()
    }

    func openSettings(hidePanel: Bool = false) {
        logger.debug("openSettings requested hidePanel=\(hidePanel, privacy: .public)")
        if hidePanel {
            self.hidePanel()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (hidePanel ? 0.12 : 0.0)) {
            SettingsWindowController.shared.present()
            self.applyWindowPrivacySettings()
        }
    }

    func captureClipboard() {
        store.captureCurrentClipboard()
    }

    func setRunInBackground(_ enabled: Bool) {
        logger.debug("setRunInBackground requested enabled=\(enabled, privacy: .public)")
        runInBackgroundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: AppPreferences.runInBackground)
        evaluateBackgroundPolicy()
    }

    func setOpenAtLogin(_ enabled: Bool) {
        logger.debug("setOpenAtLogin requested enabled=\(enabled, privacy: .public)")

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshOpenAtLoginStatus()
        } catch {
            logger.error("setOpenAtLogin failed: \(error.localizedDescription, privacy: .public)")
            SoundEffectPlayer.shared.play(.error)
            refreshOpenAtLoginStatus()
            presentOpenAtLoginAlert(error: error)
        }
    }

    func paste(_ item: ClipboardItem) {
        selectedItemID = item.id
        logger.debug("paste requested for item \(item.id.uuidString, privacy: .public) kind=\(item.kind.rawValue, privacy: .public)")
        store.copy(item)
        let pasteDestination = preferredPasteDestination()
        let targetApplication = lastTargetApplication
        pasteAutomationAvailable = ensureAccessibilityPermission(prompt: true)
        logger.debug("paste destination mode: \(pasteDestination.rawValue, privacy: .public)")
        logger.debug("paste automation available: \(self.pasteAutomationAvailable, privacy: .public)")
        logger.debug("paste target app: \(targetApplication?.localizedName ?? "nil", privacy: .public) [\(targetApplication?.bundleIdentifier ?? "nil", privacy: .public)]")

        if pasteDestination == .clipboard {
            hidePanel()
            return
        }

        guard pasteAutomationAvailable, let targetApplication else {
            logger.error("paste aborted before activation. accessibility=\(self.pasteAutomationAvailable, privacy: .public) targetAppExists=\(targetApplication != nil, privacy: .public)")
            SoundEffectPlayer.shared.play(.error)
            if !pasteAutomationAvailable {
                presentAccessibilityPermissionAlert()
            }
            return
        }

        hidePanel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.logger.debug("activating target app \(targetApplication.localizedName ?? "unknown", privacy: .public)")
            targetApplication.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                let shortcutMode = self.preferredPasteShortcutMode(for: item)
                self.logger.debug("sending paste shortcut to active app mode=\(String(describing: shortcutMode), privacy: .public)")
                self.sendPasteShortcut(mode: shortcutMode)
                SoundEffectPlayer.shared.play(.paste)
            }
        }
    }

    private func sendPasteShortcut(mode: PasteShortcutMode) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            logger.error("failed to create CGEventSource for paste shortcut")
            SoundEffectPlayer.shared.play(.error)
            return
        }
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let flags: CGEventFlags = switch mode {
        case .regular:
            .maskCommand
        case .plainText:
            [.maskCommand, .maskAlternate, .maskShift]
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        logger.debug("paste shortcut posted")
    }

    func pasteSelectedItem() {
        let visibleItems = store.visibleItems
        guard !visibleItems.isEmpty else {
            logger.error("pasteSelectedItem aborted: no visible items")
            return
        }

        let item = visibleItems.first(where: { $0.id == selectedItemID }) ?? visibleItems[0]
        logger.debug("pasteSelectedItem resolved item \(item.id.uuidString, privacy: .public), selectedItemID=\(self.selectedItemID?.uuidString ?? "nil", privacy: .public), visibleCount=\(visibleItems.count, privacy: .public)")
        paste(item)
    }

    func syncSelectionToVisibleItems(preferFirst: Bool = false) {
        let visibleItems = store.visibleItems

        guard !visibleItems.isEmpty else {
            selectedItemID = nil
            logger.debug("syncSelectionToVisibleItems cleared selection because visible list is empty")
            return
        }

        if let selectedItemID,
           visibleItems.contains(where: { $0.id == selectedItemID }),
           !preferFirst {
            return
        }

        self.selectedItemID = visibleItems.first?.id
        logger.debug("syncSelectionToVisibleItems set selection to \(self.selectedItemID?.uuidString ?? "nil", privacy: .public) preferFirst=\(preferFirst, privacy: .public)")
    }

    private func handlePanelNavigation(_ command: ClipboardPanelNavigationCommand) {
        logger.debug("panel navigation command: \(String(describing: command), privacy: .public)")
        switch command {
        case .left:
            moveItemSelection(by: -1)
        case .right:
            moveItemSelection(by: 1)
        case .up:
            moveGroupSelection(by: -1)
        case .down:
            moveGroupSelection(by: 1)
        }
    }

    private func moveItemSelection(by delta: Int) {
        let visibleItems = store.visibleItems
        guard !visibleItems.isEmpty else {
            selectedItemID = nil
            return
        }

        guard let selectedItemID,
              let currentIndex = visibleItems.firstIndex(where: { $0.id == selectedItemID }) else {
            self.selectedItemID = visibleItems.first?.id
            return
        }

        let nextIndex = (currentIndex + delta + visibleItems.count) % visibleItems.count
        self.selectedItemID = visibleItems[nextIndex].id
        logger.debug("moveItemSelection changed selection to \(self.selectedItemID?.uuidString ?? "nil", privacy: .public)")
    }

    private func moveGroupSelection(by delta: Int) {
        let groupIDs = ["all"] + store.groups.map(\.id)
        guard !groupIDs.isEmpty else { return }

        let currentIndex = groupIDs.firstIndex(of: store.selectedSourceID) ?? 0
        let nextIndex = (currentIndex + delta + groupIDs.count) % groupIDs.count
        store.selectedSourceID = groupIDs[nextIndex]
        logger.debug("moveGroupSelection changed selectedSourceID to \(self.store.selectedSourceID, privacy: .public)")
        syncSelectionToVisibleItems(preferFirst: true)
    }

    private func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.debug("accessibility permission check trusted=\(trusted, privacy: .public) prompt=\(prompt, privacy: .public)")
        return trusted
    }

    private func presentAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "AiPaste needs Accessibility access to switch back to your previous app and send Command-V automatically."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            logger.error("failed to build accessibility settings URL")
            SoundEffectPlayer.shared.play(.error)
            return
        }
        let opened = NSWorkspace.shared.open(url)
        logger.debug("open accessibility settings result=\(opened, privacy: .public)")
        if !opened {
            SoundEffectPlayer.shared.play(.error)
        }
    }

    private func preferredPasteDestination() -> PasteDestinationMode {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferences.pasteDestination) ?? PasteDestinationMode.activeApp.rawValue
        return PasteDestinationMode(rawValue: rawValue) ?? .activeApp
    }

    private func preferredPasteShortcutMode(for item: ClipboardItem) -> PasteShortcutMode {
        let alwaysPastePlainText = UserDefaults.standard.object(forKey: AppPreferences.alwaysPastePlainText) as? Bool ?? false
        guard alwaysPastePlainText, item.kind == .text || item.kind == .link else { return .regular }
        return .plainText
    }

    @objc private func handleShortcutsDidChange() {
        registerGlobalShortcuts()
    }

    private func registerGlobalShortcuts() {
        hotKeyManager.register(shortcut: shortcutManager.shortcut(for: .showPanel))
    }

    @objc private func handleBridgeCommand(_ notification: Notification) {
        guard let rawValue = notification.userInfo?[AppCommandBridge.commandKey] as? String,
              let command = AppBridgeCommand(rawValue: rawValue) else {
            return
        }

        logger.debug("received bridge command \(command.rawValue, privacy: .public)")

        switch command {
        case .showPanel:
            showPanel()
        case .hidePanel:
            hidePanel()
        case .togglePanel:
            togglePanel()
        case .openSettings:
            openSettings()
        case .captureClipboard:
            captureClipboard()
        case .reloadStore:
            store.reloadFromDisk()
            syncSelectionToVisibleItems(preferFirst: true)
        case .refreshSettings:
            refreshSettingsFromDefaults()
            applyWindowPrivacySettings()
            evaluateBackgroundPolicy()
        }
    }

    private func refreshSettingsFromDefaults() {
        let defaults = UserDefaults.standard
        runInBackgroundEnabled = defaults.object(forKey: AppPreferences.runInBackground) as? Bool ?? true
        refreshOpenAtLoginStatus()
        PrivacySettingsStore.shared.reloadFromDefaults()

        let iCloudEnabled = defaults.object(forKey: AppPreferences.iCloudSync) as? Bool ?? true
        if store.iCloudSyncEnabled != iCloudEnabled {
            store.setICloudSync(iCloudEnabled)
        }
    }

    func evaluateBackgroundPolicy() {
        let shouldRunInBackground = runInBackgroundEnabled
        let panelVisible = isPanelVisible
        let settingsVisible = SettingsWindowController.shared.isVisible
        logger.debug("evaluateBackgroundPolicy runInBackground=\(shouldRunInBackground, privacy: .public) panelVisible=\(panelVisible, privacy: .public) settingsVisible=\(settingsVisible, privacy: .public)")

        guard !shouldRunInBackground, !panelVisible, !settingsVisible else { return }

        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    func applyWindowPrivacySettings() {
        let allowScreenSharing = PrivacySettingsStore.shared.showDuringScreenSharing
        SettingsWindowController.shared.setScreenSharingVisibilityAllowed(allowScreenSharing)
        panelController.setScreenSharingVisibilityAllowed(allowScreenSharing)
    }

    private func refreshOpenAtLoginStatus() {
        let status = SMAppService.mainApp.status
        openAtLoginEnabled = status == .enabled || status == .requiresApproval
        logger.debug("refreshOpenAtLoginStatus status=\(String(describing: status), privacy: .public) enabled=\(self.openAtLoginEnabled, privacy: .public)")
    }

    private func presentOpenAtLoginAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Open at Login Unavailable"
        alert.informativeText = "AiPaste could not update the login item. Make sure the app is installed as a normal macOS app bundle, then try again.\n\n\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
