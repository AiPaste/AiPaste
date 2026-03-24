import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppCLI.isCLIInvocation() {
            NSApp.setActivationPolicy(.prohibited)
            let exitCode = AppCLI.run()
            fflush(stdout)
            fflush(stderr)
            Darwin.exit(exitCode)
        }

        NSApp.setActivationPolicy(.accessory)
        AppState.shared.start()
    }
}
