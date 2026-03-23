import AppKit
import SwiftUI

@MainActor
final class ClipboardPanelController: NSObject, NSWindowDelegate {
    private let store: ClipboardStore
    private let onVisibilityChange: (Bool) -> Void
    private var panel: ClipboardPanel?
    private var didInstallObservers = false

    init(store: ClipboardStore, onVisibilityChange: @escaping (Bool) -> Void) {
        self.store = store
        self.onVisibilityChange = onVisibilityChange
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        updateFrame(for: panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        onVisibilityChange(true)
    }

    func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
        onVisibilityChange(false)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let panel else { return }
        updateFrame(for: panel)
    }

    @objc private func handleScreenParametersChange() {
        guard let panel else { return }
        updateFrame(for: panel)
    }

    private func makePanel() -> ClipboardPanel {
        let panel = ClipboardPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: ContentView().environmentObject(store))
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.delegate = self
        panel.onEscape = { [weak self] in
            self?.hide()
        }

        if !didInstallObservers {
            didInstallObservers = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScreenParametersChange),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
        }

        return panel
    }

    private func updateFrame(for panel: NSPanel) {
        guard let screen = targetScreen() else { return }
        let screenFrame = screen.frame
        let targetHeight = min(max(screenFrame.height * 0.31, 308), 356)
        let targetFrame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: targetHeight
        )
        panel.setFrame(targetFrame, display: true)
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@MainActor
final class ClipboardPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
