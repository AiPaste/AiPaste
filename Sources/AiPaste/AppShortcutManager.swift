import AppKit
import Carbon.HIToolbox
import Foundation

extension Notification.Name {
    static let aiPasteShortcutsDidChange = Notification.Name("AiPasteShortcutsDidChange")
    static let aiPasteFocusSearch = Notification.Name("AiPasteFocusSearch")
}

enum ShortcutAction: String, CaseIterable, Identifiable {
    case showPanel
    case openSettings
    case focusSearch
    case selectFirstItem
    case selectSecondItem
    case selectThirdItem
    case selectFourthItem
    case selectFifthItem
    case selectSixthItem
    case selectSeventhItem
    case selectEighthItem
    case selectNinthItem
    case previousItem
    case nextItem
    case previousGroup
    case nextGroup
    case pasteSelectedItem
    case deleteSelectedItem
    case hidePanel

    var id: String { rawValue }

    var title: String {
        if let itemJumpIndex {
            return "Jump to Item \(itemJumpIndex + 1)"
        }

        switch self {
        case .showPanel:
            return "Show Panel"
        case .openSettings:
            return "Open Settings"
        case .focusSearch:
            return "Focus Search"
        case .selectFirstItem, .selectSecondItem, .selectThirdItem, .selectFourthItem, .selectFifthItem, .selectSixthItem, .selectSeventhItem, .selectEighthItem, .selectNinthItem:
            return "Jump to Item \(itemJumpIndex! + 1)"
        case .previousItem:
            return "Select Previous Item"
        case .nextItem:
            return "Select Next Item"
        case .previousGroup:
            return "Previous Group"
        case .nextGroup:
            return "Next Group"
        case .pasteSelectedItem:
            return "Paste Selected Item"
        case .deleteSelectedItem:
            return "Delete Selected Item"
        case .hidePanel:
            return "Hide Panel"
        }
    }

    var sectionTitle: String {
        if itemJumpIndex != nil {
            return "Panel Navigation"
        }

        switch self {
        case .showPanel, .openSettings:
            return "Global"
        case .selectFirstItem, .selectSecondItem, .selectThirdItem, .selectFourthItem, .selectFifthItem, .selectSixthItem, .selectSeventhItem, .selectEighthItem, .selectNinthItem:
            return "Panel Navigation"
        case .focusSearch, .previousItem, .nextItem, .previousGroup, .nextGroup:
            return "Panel Navigation"
        case .pasteSelectedItem, .deleteSelectedItem, .hidePanel:
            return "Panel Actions"
        }
    }

    var defaultShortcut: ShortcutDescriptor {
        if let itemJumpIndex, let keyCode = Self.digitKeyCode(for: itemJumpIndex) {
            return ShortcutDescriptor(keyCode: keyCode, modifiers: [.command])
        }

        switch self {
        case .showPanel:
            return ShortcutDescriptor(keyCode: UInt16(kVK_ANSI_V), modifiers: [.command, .shift])
        case .openSettings:
            return ShortcutDescriptor(keyCode: UInt16(kVK_ANSI_Comma), modifiers: [.command])
        case .focusSearch:
            return ShortcutDescriptor(keyCode: UInt16(kVK_ANSI_F), modifiers: [.command])
        case .selectFirstItem, .selectSecondItem, .selectThirdItem, .selectFourthItem, .selectFifthItem, .selectSixthItem, .selectSeventhItem, .selectEighthItem, .selectNinthItem:
            return ShortcutDescriptor(keyCode: Self.digitKeyCode(for: itemJumpIndex!)!, modifiers: [.command])
        case .previousItem:
            return ShortcutDescriptor(keyCode: UInt16(kVK_LeftArrow), modifiers: [])
        case .nextItem:
            return ShortcutDescriptor(keyCode: UInt16(kVK_RightArrow), modifiers: [])
        case .previousGroup:
            return ShortcutDescriptor(keyCode: UInt16(kVK_UpArrow), modifiers: [])
        case .nextGroup:
            return ShortcutDescriptor(keyCode: UInt16(kVK_DownArrow), modifiers: [])
        case .pasteSelectedItem:
            return ShortcutDescriptor(keyCode: UInt16(kVK_Return), modifiers: [])
        case .deleteSelectedItem:
            return ShortcutDescriptor(keyCode: UInt16(kVK_Delete), modifiers: [])
        case .hidePanel:
            return ShortcutDescriptor(keyCode: UInt16(kVK_Escape), modifiers: [])
        }
    }

    var itemJumpIndex: Int? {
        switch self {
        case .selectFirstItem:
            return 0
        case .selectSecondItem:
            return 1
        case .selectThirdItem:
            return 2
        case .selectFourthItem:
            return 3
        case .selectFifthItem:
            return 4
        case .selectSixthItem:
            return 5
        case .selectSeventhItem:
            return 6
        case .selectEighthItem:
            return 7
        case .selectNinthItem:
            return 8
        default:
            return nil
        }
    }

    static var itemJumpActions: [ShortcutAction] {
        allCases.filter { $0.itemJumpIndex != nil }
    }

    private static func digitKeyCode(for itemJumpIndex: Int) -> UInt16? {
        switch itemJumpIndex {
        case 0:
            return UInt16(kVK_ANSI_1)
        case 1:
            return UInt16(kVK_ANSI_2)
        case 2:
            return UInt16(kVK_ANSI_3)
        case 3:
            return UInt16(kVK_ANSI_4)
        case 4:
            return UInt16(kVK_ANSI_5)
        case 5:
            return UInt16(kVK_ANSI_6)
        case 6:
            return UInt16(kVK_ANSI_7)
        case 7:
            return UInt16(kVK_ANSI_8)
        case 8:
            return UInt16(kVK_ANSI_9)
        default:
            return nil
        }
    }
}

struct ShortcutDescriptor: Codable, Hashable {
    var keyCode: UInt16
    var modifiersRawValue: UInt

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiersRawValue = Self.normalizedModifiers(modifiers).rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        Self.normalizedModifiers(NSEvent.ModifierFlags(rawValue: modifiersRawValue))
    }

    var displayTokens: [String] {
        var tokens: [String] = []
        if modifiers.contains(.control) { tokens.append("⌃") }
        if modifiers.contains(.option) { tokens.append("⌥") }
        if modifiers.contains(.shift) { tokens.append("⇧") }
        if modifiers.contains(.command) { tokens.append("⌘") }
        tokens.append(ShortcutKeyFormatter.display(for: keyCode))
        return tokens
    }

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    static func capture(from event: NSEvent) -> ShortcutDescriptor? {
        let modifierKeyCodes: Set<UInt16> = [
            UInt16(kVK_Command), UInt16(kVK_RightCommand),
            UInt16(kVK_Shift), UInt16(kVK_RightShift),
            UInt16(kVK_Option), UInt16(kVK_RightOption),
            UInt16(kVK_Control), UInt16(kVK_RightControl),
            UInt16(kVK_CapsLock), UInt16(kVK_Function)
        ]

        guard !modifierKeyCodes.contains(event.keyCode) else { return nil }
        return ShortcutDescriptor(
            keyCode: event.keyCode,
            modifiers: normalizedModifiers(event.modifierFlags)
        )
    }

    static func normalizedModifiers(_ modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        modifiers.intersection([.command, .shift, .option, .control])
    }
}

enum ShortcutKeyFormatter {
    static func display(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return:
            return "↩"
        case kVK_Escape:
            return "esc"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_UpArrow:
            return "↑"
        case kVK_DownArrow:
            return "↓"
        case kVK_Space:
            return "Space"
        case kVK_Tab:
            return "⇥"
        case kVK_Delete:
            return "⌫"
        case kVK_ANSI_Comma:
            return ","
        case kVK_ANSI_Period:
            return "."
        case kVK_ANSI_Slash:
            return "/"
        case kVK_ANSI_Semicolon:
            return ";"
        case kVK_ANSI_Quote:
            return "'"
        case kVK_ANSI_LeftBracket:
            return "["
        case kVK_ANSI_RightBracket:
            return "]"
        case kVK_ANSI_Minus:
            return "-"
        case kVK_ANSI_Equal:
            return "="
        default:
            if let mapped = letterOrDigit(for: keyCode) {
                return mapped
            }
            return "Key \(keyCode)"
        }
    }

    private static func letterOrDigit(for keyCode: UInt16) -> String? {
        let map: [UInt16: String] = [
            UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
            UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
            UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
            UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
            UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
            UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
            UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
            UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
            UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
            UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2",
            UInt16(kVK_ANSI_3): "3", UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5",
            UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8",
            UInt16(kVK_ANSI_9): "9"
        ]
        return map[keyCode]
    }
}

@MainActor
final class AppShortcutManager: ObservableObject {
    static let shared = AppShortcutManager()

    @Published private(set) var shortcuts: [ShortcutAction: ShortcutDescriptor] = [:]

    private let defaultsKey = "app.shortcuts"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    func shortcut(for action: ShortcutAction) -> ShortcutDescriptor {
        shortcuts[action] ?? action.defaultShortcut
    }

    func update(_ action: ShortcutAction, descriptor: ShortcutDescriptor) {
        for (otherAction, otherDescriptor) in shortcuts where otherAction != action && otherDescriptor == descriptor {
            shortcuts[otherAction] = otherAction.defaultShortcut
        }
        shortcuts[action] = descriptor
        persist()
    }

    func reset(_ action: ShortcutAction) {
        shortcuts[action] = action.defaultShortcut
        persist()
    }

    func resetAll() {
        shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, $0.defaultShortcut) })
        persist()
    }

    func matches(_ event: NSEvent, action: ShortcutAction) -> Bool {
        let shortcut = shortcut(for: action)
        let eventModifiers = ShortcutDescriptor.normalizedModifiers(event.modifierFlags)
        return shortcut.keyCode == event.keyCode && shortcut.modifiers == eventModifiers
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? decoder.decode([String: ShortcutDescriptor].self, from: data) else {
            shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, $0.defaultShortcut) })
            return
        }

        var loaded: [ShortcutAction: ShortcutDescriptor] = [:]
        for action in ShortcutAction.allCases {
            loaded[action] = decoded[action.rawValue] ?? action.defaultShortcut
        }
        shortcuts = loaded
    }

    private func persist() {
        let encoded = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        if let data = try? encoder.encode(encoded) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        NotificationCenter.default.post(name: .aiPasteShortcutsDidChange, object: nil)
    }
}
