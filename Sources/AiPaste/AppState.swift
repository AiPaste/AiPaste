import AppKit
import ApplicationServices
import Carbon
import Foundation
import OSLog

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let store = ClipboardStore()
    @Published private(set) var isPanelVisible = false
    @Published private(set) var pasteAutomationAvailable = AXIsProcessTrusted()
    @Published var selectedItemID: UUID?

    private let logger = Logger(subsystem: "AiPaste", category: "AppState")
    private var lastTargetApplication: NSRunningApplication?

    private lazy var panelController = ClipboardPanelController(
        store: store,
        onVisibilityChange: { [weak self] isVisible in
            self?.isPanelVisible = isVisible
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

    private init() {}

    func start() {
        pasteAutomationAvailable = ensureAccessibilityPermission(prompt: false)
        hotKeyManager.register()
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
        }
    }

    func captureClipboard() {
        store.captureCurrentClipboard()
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
                self.logger.debug("sending paste shortcut to active app")
                self.sendPasteShortcut()
            }
        }
    }

    private func sendPasteShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            logger.error("failed to create CGEventSource for paste shortcut")
            return
        }
        let keyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand

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
            return
        }
        let opened = NSWorkspace.shared.open(url)
        logger.debug("open accessibility settings result=\(opened, privacy: .public)")
    }

    private func preferredPasteDestination() -> PasteDestinationMode {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferences.pasteDestination) ?? PasteDestinationMode.activeApp.rawValue
        return PasteDestinationMode(rawValue: rawValue) ?? .activeApp
    }
}
