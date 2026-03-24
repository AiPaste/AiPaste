import SwiftUI

@main
struct AiPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            Button(appState.isPanelVisible ? "Hide Panel" : "Show Panel") {
                appState.togglePanel()
            }

            Button("Settings...") {
                appState.openSettings()
            }

            Button("Capture Clipboard") {
                appState.captureClipboard()
            }

            Divider()

            Button("Quit AiPaste") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(nsImage: MenuBarIconProvider.image)
                .accessibilityLabel("AiPaste")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
    }
}
