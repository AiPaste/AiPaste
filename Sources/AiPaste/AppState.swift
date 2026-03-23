import AppKit
import ApplicationServices
import Carbon
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let store = ClipboardStore()
    @Published private(set) var isPanelVisible = false
    @Published private(set) var pasteAutomationAvailable = AXIsProcessTrusted()
    @Published var selectedItemID: UUID?

    private var lastTargetApplication: NSRunningApplication?

    private lazy var panelController = ClipboardPanelController(
        store: store,
        onVisibilityChange: { [weak self] isVisible in
            self?.isPanelVisible = isVisible
        },
        onNavigationCommand: { [weak self] command in
            self?.handlePanelNavigation(command)
        }
    )
    private lazy var hotKeyManager = GlobalHotKeyManager {
        Task { @MainActor in
            AppState.shared.showPanel()
        }
    }

    private init() {}

    func start() {
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
        }
        panelController.show()
        syncSelectionToVisibleItems(preferFirst: true)
    }

    func hidePanel() {
        panelController.hide()
    }

    func captureClipboard() {
        store.captureCurrentClipboard()
    }

    func paste(_ item: ClipboardItem) {
        selectedItemID = item.id
        store.copy(item)
        pasteAutomationAvailable = AXIsProcessTrusted()
        let targetApplication = lastTargetApplication
        hidePanel()

        guard pasteAutomationAvailable, let targetApplication else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            targetApplication.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                self.sendPasteShortcut()
            }
        }
    }

    private func sendPasteShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    func syncSelectionToVisibleItems(preferFirst: Bool = false) {
        let visibleItems = store.visibleItems

        guard !visibleItems.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID,
           visibleItems.contains(where: { $0.id == selectedItemID }),
           !preferFirst {
            return
        }

        self.selectedItemID = visibleItems.first?.id
    }

    private func handlePanelNavigation(_ command: ClipboardPanelNavigationCommand) {
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
    }

    private func moveGroupSelection(by delta: Int) {
        let groupIDs = ["all"] + store.groups.map(\.id)
        guard !groupIDs.isEmpty else { return }

        let currentIndex = groupIDs.firstIndex(of: store.selectedSourceID) ?? 0
        let nextIndex = (currentIndex + delta + groupIDs.count) % groupIDs.count
        store.selectedSourceID = groupIDs[nextIndex]
        syncSelectionToVisibleItems(preferFirst: true)
    }
}
