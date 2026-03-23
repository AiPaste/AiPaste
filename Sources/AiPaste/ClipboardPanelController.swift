import AppKit
import OSLog
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
    private let onConfirmSelection: () -> Void
    private let onOpenSettings: () -> Void
    private var panel: ClipboardPanel?
    private var didInstallObservers = false
    private var isAnimatingTransition = false
    private var keyEventMonitor: Any?
    private let logger = Logger(subsystem: "AiPaste", category: "Panel")

    private let animationOffset: CGFloat = 56
    private let animationDuration: TimeInterval = 0.22

    init(
        store: ClipboardStore,
        onVisibilityChange: @escaping (Bool) -> Void,
        onNavigationCommand: @escaping (ClipboardPanelNavigationCommand) -> Void,
        onConfirmSelection: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.store = store
        self.onVisibilityChange = onVisibilityChange
        self.onNavigationCommand = onNavigationCommand
        self.onConfirmSelection = onConfirmSelection
        self.onOpenSettings = onOpenSettings
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        guard let targetFrame = targetFrame() else { return }
        installKeyEventMonitorIfNeeded()
        logger.debug("show panel requested")

        if panel.isVisible, !isAnimatingTransition {
            panel.setFrame(targetFrame, display: true)
            NSApp.activate(ignoringOtherApps: true)
            panel.orderFrontRegardless()
            panel.makeKey()
            logger.debug("panel already visible; refreshed frame and key state")
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
        logger.debug("panel animation start")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isAnimatingTransition = false
                self.logger.debug("panel animation completed; visible=true")
                self.onVisibilityChange(true)
            }
        }
    }

    func hide() {
        guard let panel else { return }
        guard panel.isVisible, !isAnimatingTransition else { return }
        guard let targetFrame = targetFrame() else { return }
        logger.debug("hide panel requested")

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
                self.removeKeyEventMonitor()
                self.logger.debug("panel hide completed; visible=false")
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
        panel.onConfirmSelection = onConfirmSelection
        panel.onOpenSettings = onOpenSettings

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

    private func installKeyEventMonitorIfNeeded() {
        guard keyEventMonitor == nil else { return }
        logger.debug("installing local key event monitor")

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }
            self.logger.debug("local key monitor received keyCode=\(event.keyCode, privacy: .public)")

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
               event.charactersIgnoringModifiers == "," {
                self.logger.debug("local key monitor opening settings via Command-Comma")
                self.onOpenSettings()
                return nil
            }

            switch event.keyCode {
            case 53:
                self.onConfirmOrEscape(.escape)
                return nil
            case 36, 76:
                self.onConfirmOrEscape(.confirm)
                return nil
            case 123:
                self.onNavigationCommand(.left)
                return nil
            case 124:
                self.onNavigationCommand(.right)
                return nil
            case 125:
                self.onNavigationCommand(.down)
                return nil
            case 126:
                self.onNavigationCommand(.up)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyEventMonitor() {
        guard let keyEventMonitor else { return }
        NSEvent.removeMonitor(keyEventMonitor)
        self.keyEventMonitor = nil
        logger.debug("removed local key event monitor")
    }

    private func onConfirmOrEscape(_ action: PanelKeyAction) {
        logger.debug("panel key action: \(String(describing: action), privacy: .public)")
        switch action {
        case .confirm:
            onConfirmSelection()
        case .escape:
            hide()
        }
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

private enum PanelKeyAction {
    case confirm
    case escape
}

@MainActor
final class ClipboardPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onNavigationCommand: ((ClipboardPanelNavigationCommand) -> Void)?
    var onConfirmSelection: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    private let logger = Logger(subsystem: "AiPaste", category: "PanelWindow")

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        logger.debug("panel keyDown received keyCode=\(event.keyCode, privacy: .public)")

        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers == "," {
            onOpenSettings?()
            return
        }

        switch event.keyCode {
        case 53:
            onEscape?()
            return
        case 36, 76:
            onConfirmSelection?()
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

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        logger.debug("panel performKeyEquivalent received keyCode=\(event.keyCode, privacy: .public)")
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers == "," {
            onOpenSettings?()
            return true
        }
        switch event.keyCode {
        case 36, 76:
            onConfirmSelection?()
            return true
        case 53:
            onEscape?()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
