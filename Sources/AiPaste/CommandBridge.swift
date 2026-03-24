import Foundation

enum AppBridgeCommand: String {
    case showPanel
    case hidePanel
    case togglePanel
    case openSettings
    case captureClipboard
    case reloadStore
    case refreshSettings
}

enum AppCommandBridge {
    static let commandNotification = Notification.Name("AiPaste.CommandBridge.Command")
    static let commandKey = "command"

    static func post(_ command: AppBridgeCommand) {
        DistributedNotificationCenter.default().postNotificationName(
            commandNotification,
            object: nil,
            userInfo: [commandKey: command.rawValue],
            deliverImmediately: true
        )
    }
}
