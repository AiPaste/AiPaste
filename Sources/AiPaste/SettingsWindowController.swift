import AppKit
import SwiftUI

enum PasteDestinationMode: String {
    case activeApp
    case clipboard
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case privacy
    case shortcuts
    case subscription

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .privacy:
            return "Privacy"
        case .shortcuts:
            return "Shortcuts"
        case .subscription:
            return "Subscription"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .privacy:
            return "hand.raised"
        case .shortcuts:
            return "keyboard"
        case .subscription:
            return "checkmark.seal"
        }
    }
}

enum AppPreferences {
    static let openAtLogin = "settings.openAtLogin"
    static let runInBackground = "settings.runInBackground"
    static let iCloudSync = "settings.iCloudSync"
    static let soundEffects = "settings.soundEffects"
    static let pasteDestination = "settings.pasteDestination"
    static let alwaysPastePlainText = "settings.alwaysPastePlainText"
    static let historyRetention = "settings.historyRetention"
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    private init() {
        let rootView = SettingsRootView()
            .environmentObject(AppState.shared)
        let hostingView = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = NSColor(calibratedWhite: 0.14, alpha: 1)
        window.toolbarStyle = .unifiedCompact
        window.contentView = hostingView

        super.init(window: window)
        self.window?.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppState.shared.evaluateBackgroundPolicy()
    }
}

private struct SettingsRootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPane: SettingsPane = .general
    @AppStorage(AppPreferences.iCloudSync) private var iCloudSync = true
    @AppStorage(AppPreferences.soundEffects) private var soundEffects = true
    @AppStorage(AppPreferences.pasteDestination) private var pasteDestinationRaw = PasteDestinationMode.activeApp.rawValue
    @AppStorage(AppPreferences.alwaysPastePlainText) private var alwaysPastePlainText = false
    @AppStorage(AppPreferences.historyRetention) private var historyRetention = 2.0

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
                .overlay(Color.white.opacity(0.08))
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.17, green: 0.17, blue: 0.18))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(SettingsPane.allCases) { pane in
                    SettingsSidebarItem(
                        title: pane.title,
                        icon: pane.icon,
                        isSelected: selectedPane == pane
                    ) {
                        selectedPane = pane
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                if let url = URL(string: "https://support.apple.com") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11, weight: .medium))
                    Text("Help Center")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.92))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 5)
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(width: 164, alignment: .topLeading)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedPane {
        case .general:
            generalPane
        case .privacy:
            placeholderPane(
                title: "Privacy",
                message: "Accessibility and clipboard permissions are managed by macOS System Settings."
            )
        case .shortcuts:
            placeholderPane(
                title: "Shortcuts",
                message: "Use Shift-Command-V to show the panel, and Command-Comma to open Settings while the panel is visible."
            )
        case .subscription:
            placeholderPane(
                title: "Subscription",
                message: "Subscription management is not connected yet."
            )
        }
    }

    private var generalPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("General")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.96))

                SettingsCard {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            title: "Open at login",
                            isOn: Binding(
                                get: { appState.openAtLoginEnabled },
                                set: { appState.setOpenAtLogin($0) }
                            )
                        )
                        SettingsToggleRow(
                            title: "Run in background",
                            isOn: Binding(
                                get: { appState.runInBackgroundEnabled },
                                set: { appState.setRunInBackground($0) }
                            )
                        )
                        SettingsToggleRow(title: "iCloud sync", trailingText: "Synced now", isOn: $iCloudSync)
                        SettingsToggleRow(title: "Sound effects", isOn: $soundEffects, showsDivider: false)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste Items")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 0) {
                            PasteDestinationOption(
                                title: "To active app",
                                subtitle: "Paste selected items directly to the application you are currently using.",
                                isSelected: pasteDestination == .activeApp,
                                illustration: true
                            ) {
                                pasteDestination = .activeApp
                            }

                            PasteDestinationOption(
                                title: "To clipboard",
                                subtitle: "Copy selected items to the system clipboard to paste manually later.",
                                isSelected: pasteDestination == .clipboard,
                                illustration: false
                            ) {
                                pasteDestination = .clipboard
                            }

                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.vertical, 9)

                            Toggle(isOn: $alwaysPastePlainText) {
                                Text("Always paste as Plain Text")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.92))
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Keep History")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Slider(value: $historyRetention, in: 0...4, step: 1)
                                .tint(Color(red: 0.15, green: 0.48, blue: 0.94))

                            HStack {
                                ForEach(Array(retentionLabels.enumerated()), id: \.offset) { index, label in
                                    Text(label)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(index == Int(historyRetention) ? 0.92 : 0.78))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            Divider()
                                .overlay(Color.white.opacity(0.08))

                            HStack {
                                Spacer(minLength: 0)
                                Button("Erase History...") {
                                    appState.store.clearAll()
                                }
                                .buttonStyle(SettingsSecondaryButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func placeholderPane(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.96))

            SettingsCard {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var retentionLabels: [String] {
        ["Day", "Week", "Month", "Year", "Forever"]
    }

    private var pasteDestination: PasteDestinationMode {
        get { PasteDestinationMode(rawValue: pasteDestinationRaw) ?? .activeApp }
        nonmutating set { pasteDestinationRaw = newValue.rawValue }
    }
}

private struct SettingsSidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.white.opacity(0.94))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                        ? LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.44, blue: 0.92),
                                Color(red: 0.06, green: 0.32, blue: 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct SettingsToggleRow: View {
    let title: String
    var trailingText: String? = nil
    @Binding var isOn: Bool
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))

                Spacer(minLength: 0)

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .padding(.trailing, 8)
                }

                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.regular)
            }
            .padding(.vertical, 10)

            if showsDivider {
                Divider()
                    .overlay(Color.white.opacity(0.08))
            }
        }
    }
}

private struct PasteDestinationOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let illustration: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(red: 0.16, green: 0.48, blue: 0.94) : Color.white.opacity(0.10))
                        .frame(width: 18, height: 18)

                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: isSelected ? 5 : 0, height: isSelected ? 5 : 0)
                }
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                if illustration {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.86, green: 0.39, blue: 0.02),
                                    Color(red: 0.93, green: 0.58, blue: 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(alignment: .center) {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.white.opacity(0.88))
                                    .frame(width: 16, height: 16)
                                VStack(alignment: .leading, spacing: 3) {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(Color.black.opacity(0.55))
                                        .frame(width: 38, height: 6)
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(Color.black.opacity(0.40))
                                        .frame(width: 28, height: 6)
                                }
                            }
                        }
                        .frame(width: 100, height: 68)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 1)
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.09))
            )
    }
}
