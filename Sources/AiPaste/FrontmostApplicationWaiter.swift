import AppKit
import Foundation

enum FrontmostApplicationWaiter {
    private static let pollingInterval: TimeInterval = 0.03

    @MainActor
    static func wait(
        for application: NSRunningApplication,
        timeout: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            let deadline = Date().addingTimeInterval(timeout)

            while Date() < deadline {
                if isFrontmost(application) {
                    completion(true)
                    return
                }

                try? await Task.sleep(for: .seconds(pollingInterval))
            }

            completion(isFrontmost(application))
        }
    }

    @discardableResult
    static func waitBlocking(for application: NSRunningApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if isFrontmost(application) {
                return true
            }
            usleep(useconds_t(pollingInterval * 1_000_000))
        }

        return false
    }

    static func isFrontmost(_ application: NSRunningApplication) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
    }
}
