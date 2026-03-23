import AppKit
import SwiftUI

enum ClipboardPanelNavigationCommand {
    case left
    case right
    case up
    case down
}

@MainActor
final class ClipboardPanelController: NSObject, NSWindowDelegate {
    private let store: ClipboardStore
    private let onVisibilityChange: (Bool) -> Void
    private let onNavigationCommand: (ClipboardPanelNavigationCommand) -> Void
    private var panel: ClipboardPanel?
    private var didInstallObservers = false
    private var isAnimatingTransition = false

    private let animationOffset: CGFloat = 56
    private let animationDuration: TimeInterval = 0.22

    init(
        store: ClipboardStore,
        onVisibilityChange: @escaping (Bool) -> Void,
        onNavigationCommand: @escaping (ClipboardPanelNavigationCommand) -> Void
    ) {
        self.store = store
        self.onVisibilityChange = onVisibilityChange
        self.onNavigationCommand = onNavigationCommand
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        guard let targetFrame = targetFrame() else { return }

        if panel.isVisible, !isAnimatingTransition {
            panel.setFrame(targetFrame, display: true)
            NSApp.activate(ignoringOtherApps: true)
            panel.orderFrontRegardless()
            panel.makeKey()
            onVisibilityChange(true)
            return
        }

        let startFrame = targetFrame.offsetBy(dx: 0, dy: -animationOffset)
        isAnimatingTransition = true

        panel.alphaValue = 0
        panel.setFrame(startFrame, display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isAnimatingTransition = false
                self.onVisibilityChange(true)
            }
        }
    }

    func hide() {
        guard let panel else { return }
        guard panel.isVisible, !isAnimatingTransition else { return }
        guard let targetFrame = targetFrame() else { return }

        let endFrame = targetFrame.offsetBy(dx: 0, dy: -animationOffset)
        isAnimatingTransition = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor in
                guard let self, let panel else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
                panel.setFrame(targetFrame, display: false)
                self.isAnimatingTransition = false
                self.onVisibilityChange(false)
            }
        }
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
        panel.onNavigationCommand = onNavigationCommand

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
        guard let targetFrame = targetFrame() else { return }
        panel.setFrame(targetFrame, display: true)
    }

    private func targetFrame() -> NSRect? {
        guard let screen = targetScreen() else { return nil }
        let screenFrame = screen.frame
        let targetHeight = min(max(screenFrame.height * 0.31, 308), 356)
        return NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: targetHeight
        )
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
    var onNavigationCommand: ((ClipboardPanelNavigationCommand) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            onEscape?()
            return
        case 123:
            onNavigationCommand?(.left)
            return
        case 124:
            onNavigationCommand?(.right)
            return
        case 125:
            onNavigationCommand?(.down)
            return
        case 126:
            onNavigationCommand?(.up)
            return
        default:
            break
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
