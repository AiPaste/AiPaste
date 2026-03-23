import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let store = ClipboardStore()
    @Published private(set) var isPanelVisible = false

    private lazy var panelController = ClipboardPanelController(store: store) { [weak self] isVisible in
        self?.isPanelVisible = isVisible
    }
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
        panelController.show()
    }

    func hidePanel() {
        panelController.hide()
    }

    func captureClipboard() {
        store.captureCurrentClipboard()
    }
}
