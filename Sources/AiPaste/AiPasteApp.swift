import SwiftUI

@main
struct AiPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("AiPaste", systemImage: "doc.on.clipboard.fill") {
            Button(appState.isPanelVisible ? "Hide Panel" : "Show Panel") {
                appState.togglePanel()
            }

            Button("Settings...") {
                appState.openSettings()
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button("Capture Clipboard") {
                appState.captureClipboard()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Divider()

            Button("Quit AiPaste") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
    }
}
