import AppKit
import Carbon.HIToolbox
import SwiftUI

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
        window.backgroundColor = AppThemePalette.windowBackgroundNSColor
        window.sharingType = PrivacySettingsStore.shared.showDuringScreenSharing ? .readOnly : .none
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

    func setScreenSharingVisibilityAllowed(_ allowed: Bool) {
        window?.sharingType = allowed ? .readOnly : .none
    }

    func windowWillClose(_ notification: Notification) {
        AppState.shared.evaluateBackgroundPolicy()
    }
}

private struct SettingsRootView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var shortcutManager = AppShortcutManager.shared
    @ObservedObject private var store = AppState.shared.store
    @ObservedObject private var privacyStore = PrivacySettingsStore.shared
    @ObservedObject private var updateManager = AppUpdateManager.shared
    @ObservedObject private var cliToolInstaller = CLIToolInstaller.shared
    @StateObject private var shortcutRecorder = ShortcutRecordingController()
    @State private var selectedPane: SettingsPane = .general
    @State private var selectedIgnoredApplicationID: String?
    @AppStorage(AppPreferences.soundEffects) private var soundEffects = true
    @AppStorage(AppPreferences.pasteDestination) private var pasteDestinationRaw = PasteDestinationMode.activeApp.rawValue
    @AppStorage(AppPreferences.alwaysPastePlainText) private var alwaysPastePlainText = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
                .overlay(AppThemePalette.divider)
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppThemePalette.windowBackground)
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

            VStack(alignment: .leading, spacing: 6) {
                Button(updateManager.isChecking ? "Checking…" : "Check for Updates") {
                    Task {
                        await updateManager.checkForUpdates(userInitiated: true)
                    }
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .disabled(updateManager.isChecking)

                Text(updateManager.updateStatusMessage)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppThemePalette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 8)

            Text(versionLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppThemePalette.textFaint)
                .padding(.bottom, 2)

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
                .foregroundStyle(AppThemePalette.textPrimary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 5)
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(width: 164, alignment: .topLeading)
        .background(AppThemePalette.sidebarBackground)
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedPane {
        case .general:
            generalPane
        case .privacy:
            privacyPane
        case .shortcuts:
            shortcutsPane
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
                    .foregroundStyle(AppThemePalette.textPrimary)

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
                        SettingsToggleRow(
                            title: "Automatic updates",
                            trailingText: updateManager.availableVersion.map { "v\($0) available" },
                            isOn: Binding(
                                get: { updateManager.automaticUpdatesEnabled },
                                set: { updateManager.setAutomaticUpdates($0) }
                            )
                        )
                        SettingsToggleRow(
                            title: "iCloud sync",
                            trailingText: iCloudStatusText,
                            isOn: Binding(
                                get: { store.iCloudSyncEnabled },
                                set: { store.setICloudSync($0) }
                            )
                        )
                        SettingsToggleRow(title: "Sound effects", isOn: $soundEffects, showsDivider: false)
                    }
                }

                SettingsCard {
                    ThemeSelectionRow(
                        themeMode: appState.themeManager.themeMode,
                        onSelect: { appState.setThemeMode($0) }
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste Items")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppThemePalette.textPrimary)

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
                                .overlay(AppThemePalette.divider)
                                .padding(.vertical, 9)

                            Toggle(isOn: $alwaysPastePlainText) {
                                Text("Always paste as Plain Text")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppThemePalette.textPrimary)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Keep History")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppThemePalette.textPrimary)

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Slider(
                                value: Binding(
                                    get: { Double(currentHistoryRetention.rawValue) },
                                    set: { newValue in
                                        if let retention = HistoryRetention(rawValue: Int(newValue.rounded())) {
                                            store.setHistoryRetention(retention)
                                        }
                                    }
                                ),
                                in: 0...4,
                                step: 1
                            )
                                .tint(Color(red: 0.15, green: 0.48, blue: 0.94))

                            HStack {
                                ForEach(Array(retentionLabels.enumerated()), id: \.offset) { index, label in
                                    Text(label)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(index == currentHistoryRetention.rawValue ? AppThemePalette.textPrimary : AppThemePalette.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            Divider()
                                .overlay(AppThemePalette.divider)

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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Command Line")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppThemePalette.textPrimary)

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Install the `aipaste` command into `~/.local/bin` and add that directory to your shell PATH.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppThemePalette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(alignment: .leading, spacing: 4) {
                                Label(cliToolInstaller.commandPath, systemImage: "terminal")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppThemePalette.textPrimary)

                                Label(cliToolInstaller.shellConfigPath, systemImage: "text.alignleft")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppThemePalette.textMuted)
                            }

                            HStack(spacing: 10) {
                                Button(cliToolInstaller.isInstalled ? "Reinstall CLI to PATH" : "Install CLI to PATH") {
                                    cliToolInstaller.install()
                                }
                                .buttonStyle(SettingsSecondaryButtonStyle())

                                Button("Refresh") {
                                    cliToolInstaller.refreshStatus()
                                }
                                .buttonStyle(SettingsSecondaryButtonStyle())
                            }

                            Text(cliToolInstaller.statusMessage)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(cliToolInstaller.isInstalled ? AppThemePalette.textTertiary : AppThemePalette.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var shortcutsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Shortcuts")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppThemePalette.textPrimary)

                SettingsCard {
                    Text("Current shortcuts are listed below. Global shortcuts work from anywhere; panel shortcuts only work while the panel is visible.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppThemePalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ShortcutSectionCard(
                    title: "Global",
                    actions: ShortcutAction.allCases.filter { $0.sectionTitle == "Global" },
                    shortcutManager: shortcutManager,
                    recorder: shortcutRecorder
                )

                ShortcutSectionCard(
                    title: "Panel Navigation",
                    actions: ShortcutAction.allCases.filter { $0.sectionTitle == "Panel Navigation" },
                    shortcutManager: shortcutManager,
                    recorder: shortcutRecorder
                )

                ShortcutSectionCard(
                    title: "Panel Actions",
                    actions: ShortcutAction.allCases.filter { $0.sectionTitle == "Panel Actions" },
                    shortcutManager: shortcutManager,
                    recorder: shortcutRecorder
                )

                HStack {
                    Spacer(minLength: 0)

                    Button("Reset shortcuts to default…") {
                        shortcutManager.resetAll()
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var privacyPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppThemePalette.textPrimary)

                SettingsCard {
                    VStack(spacing: 0) {
                        PrivacyToggleRow(
                            title: "Show during screen sharing",
                            subtitle: "Allow Paste windows to appear to others when you share your screen.",
                            isOn: Binding(
                                get: { privacyStore.showDuringScreenSharing },
                                set: { privacyStore.setShowDuringScreenSharing($0) }
                            )
                        )
                        PrivacyToggleRow(
                            title: "Generate link previews",
                            subtitle: "Download page metadata for links so cards can show richer previews.",
                            isOn: Binding(
                                get: { privacyStore.generateLinkPreviews },
                                set: { privacyStore.setGenerateLinkPreviews($0) }
                            ),
                            showsDivider: false
                        )
                    }
                }

                SettingsCard {
                    VStack(spacing: 0) {
                        PrivacyToggleRow(
                            title: "Ignore confidential content",
                            subtitle: "Skip saving likely passwords, tokens, secrets, and private keys when detected.",
                            isOn: Binding(
                                get: { privacyStore.ignoreConfidentialContent },
                                set: { privacyStore.setIgnoreConfidentialContent($0) }
                            )
                        )
                        PrivacyToggleRow(
                            title: "Ignore transient content",
                            subtitle: "Skip one-time codes, verification codes, and other temporary copied values.",
                            isOn: Binding(
                                get: { privacyStore.ignoreTransientContent },
                                set: { privacyStore.setIgnoreTransientContent($0) }
                            ),
                            showsDivider: false
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Ignore Applications")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppThemePalette.textPrimary)

                    Text("Do not save content copied from the applications below.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppThemePalette.textSecondary)

                    SettingsCard {
                        VStack(spacing: 0) {
                            if privacyStore.ignoredApplications.isEmpty {
                                Text("No ignored applications yet.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppThemePalette.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(Array(privacyStore.ignoredApplications.enumerated()), id: \.element.id) { index, application in
                                    IgnoredApplicationRow(
                                        application: application,
                                        icon: privacyStore.appIcon(for: application),
                                        isSelected: selectedIgnoredApplicationID == application.id,
                                        onRemove: {
                                            privacyStore.removeIgnoredApplication(bundleIdentifier: application.bundleIdentifier)
                                            if selectedIgnoredApplicationID == application.bundleIdentifier {
                                                selectedIgnoredApplicationID = nil
                                            }
                                        }
                                    ) {
                                        selectedIgnoredApplicationID = application.id
                                    }

                                    if index < privacyStore.ignoredApplications.count - 1 {
                                        Divider()
                                            .overlay(AppThemePalette.divider)
                                    }
                                }
                            }

                            Divider()
                                .overlay(AppThemePalette.divider)
                                .padding(.top, 8)

                            HStack(spacing: 8) {
                                Button {
                                    if let application = privacyStore.chooseAndAddIgnoredApplication() {
                                        selectedIgnoredApplicationID = application.bundleIdentifier
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)

                                Menu {
                                    Button("Choose Application…") {
                                        if let application = privacyStore.chooseAndAddIgnoredApplication() {
                                            selectedIgnoredApplicationID = application.bundleIdentifier
                                        }
                                    }

                                    if !privacyStore.availableApplicationsToIgnore.isEmpty {
                                        Divider()

                                        ForEach(privacyStore.availableApplicationsToIgnore) { application in
                                            Button(application.name) {
                                                if let ignoredApplication = privacyStore.addIgnoredApplication(
                                                    bundleIdentifier: application.bundleIdentifier,
                                                    name: application.name
                                                ) {
                                                    selectedIgnoredApplicationID = ignoredApplication.bundleIdentifier
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .bold))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    if let selectedIgnoredApplicationID {
                                        privacyStore.removeIgnoredApplication(bundleIdentifier: selectedIgnoredApplicationID)
                                        self.selectedIgnoredApplicationID = nil
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedIgnoredApplicationID == nil)
                            }
                            .foregroundStyle(AppThemePalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
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
                .foregroundStyle(AppThemePalette.textPrimary)

            SettingsCard {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppThemePalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var retentionLabels: [String] {
        HistoryRetention.allCases.map(\.title)
    }

    private var pasteDestination: PasteDestinationMode {
        get { PasteDestinationMode(rawValue: pasteDestinationRaw) ?? .activeApp }
        nonmutating set { pasteDestinationRaw = newValue.rawValue }
    }

    private var currentHistoryRetention: HistoryRetention {
        let rawValue = UserDefaults.standard.object(forKey: AppPreferences.historyRetention) as? Int ?? HistoryRetention.month.rawValue
        return HistoryRetention(rawValue: rawValue) ?? .month
    }

    private var iCloudStatusText: String? {
        guard store.iCloudSyncEnabled else { return "Off" }
        guard let lastSyncDate = store.lastSyncDate else { return "Waiting" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastSyncDate, relativeTo: .now)
    }

    private var versionLabel: String {
        let version = AppVersion.displayString
        return version == "Unknown" ? "Version Development" : "Version \(version)"
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
            .foregroundStyle(AppThemePalette.textPrimary)
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

private struct PrivacyToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppThemePalette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppThemePalette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.regular)
            }
            .padding(.vertical, 10)

            if showsDivider {
                Divider()
                    .overlay(AppThemePalette.divider)
            }
        }
    }
}

private struct IgnoredApplicationRow: View {
    let application: IgnoredApplication
    let icon: NSImage?
    let isSelected: Bool
    let onRemove: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppThemePalette.controlSurface)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppThemePalette.textSecondary)
                    )
            }

            Text(application.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppThemePalette.textPrimary)

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppThemePalette.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppThemePalette.controlSurface)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? AppThemePalette.selectedSurface : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

private struct ShortcutSectionCard: View {
    let title: String
    let actions: [ShortcutAction]
    @ObservedObject var shortcutManager: AppShortcutManager
    @ObservedObject var recorder: ShortcutRecordingController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppThemePalette.textPrimary)

            SettingsCard {
                VStack(spacing: 0) {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        ShortcutRow(
                            action: action,
                            shortcut: shortcutManager.shortcut(for: action),
                            isRecording: recorder.recordingAction == action,
                            onRecord: {
                                recorder.startRecording(for: action) { descriptor in
                                    shortcutManager.update(action, descriptor: descriptor)
                                }
                            },
                            onReset: {
                                shortcutManager.reset(action)
                            }
                        )

                        if index < actions.count - 1 {
                            Divider()
                                .overlay(AppThemePalette.divider)
                        }
                    }
                }
            }
        }
    }
}

private struct ShortcutRow: View {
    let action: ShortcutAction
    let shortcut: ShortcutDescriptor
    let isRecording: Bool
    let onRecord: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(action.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppThemePalette.textPrimary)

            Spacer(minLength: 0)

            Button(action: onRecord) {
                HStack(spacing: 6) {
                    ForEach(displayTokens, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppThemePalette.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppThemePalette.controlSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(AppThemePalette.controlBorder, lineWidth: 1)
                                    )
                            )
                    }
                }
                .frame(minWidth: 112, alignment: .trailing)
            }
            .buttonStyle(.plain)

            Button(action: onReset) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppThemePalette.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var displayTokens: [String] {
        isRecording ? ["Type", "Shortcut"] : shortcut.displayTokens
    }
}

@MainActor
private final class ShortcutRecordingController: ObservableObject {
    @Published var recordingAction: ShortcutAction?

    private var monitor: Any?

    func startRecording(for action: ShortcutAction, onRecord: @escaping (ShortcutDescriptor) -> Void) {
        stopRecording()
        recordingAction = action

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == UInt16(kVK_Escape), event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                self.stopRecording()
                return nil
            }

            guard let descriptor = ShortcutDescriptor.capture(from: event) else {
                return nil
            }

            onRecord(descriptor)
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        recordingAction = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
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
                .fill(AppThemePalette.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppThemePalette.cardBorder, lineWidth: 1)
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
                    .foregroundStyle(AppThemePalette.textPrimary)

                Spacer(minLength: 0)

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppThemePalette.textMuted)
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
                    .overlay(AppThemePalette.divider)
            }
        }
    }
}

private struct ThemeSelectionRow: View {
    let themeMode: AppThemeMode
    let onSelect: (AppThemeMode) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Theme")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppThemePalette.textPrimary)

                Text("Use light, dark, or match your system")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppThemePalette.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                ForEach(AppThemeMode.allCases) { mode in
                    ThemeModeChip(
                        mode: mode,
                        isSelected: themeMode == mode,
                        action: { onSelect(mode) }
                    )
                }
            }
            .padding(4)
            .background(
                Capsule(style: .continuous)
                    .fill(AppThemePalette.segmentedBackground)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThemeModeChip: View {
    let mode: AppThemeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .medium))
                    Text(modeLabel)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isSelected ? AppThemePalette.textPrimary : AppThemePalette.textSecondary)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? AppThemePalette.segmentedSelectedBackground : Color.clear)
                )
            }
            .padding(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(-6)
    }

    private var modeLabel: String {
        switch mode {
        case .system:
            return "System"
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        }
    }

    private var iconName: String {
        switch mode {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .system:
            return "laptopcomputer"
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
                        .fill(isSelected ? Color(red: 0.16, green: 0.48, blue: 0.94) : AppThemePalette.controlSurface)
                        .frame(width: 18, height: 18)

                    Circle()
                        .fill(AppThemePalette.selectionDot)
                        .frame(width: isSelected ? 5 : 0, height: isSelected ? 5 : 0)
                }
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppThemePalette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppThemePalette.textMuted)
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
            .foregroundStyle(AppThemePalette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? AppThemePalette.selectedSurface : AppThemePalette.controlSurface)
            )
    }
}
