import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ClipboardStore
    @State private var editingGroupID: String?
    @State private var editingGroupTitle = ""
    @State private var activeGroupMenuID: String?

    var body: some View {
        ZStack {
            panelShell

            VStack(spacing: 18) {
                toolbar
                cardsStrip
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .overlayPreferenceValue(GroupFramePreferenceKey.self) { preferences in
            GeometryReader { proxy in
                if let menuGroupID = activeGroupMenuID,
                   let anchor = preferences[menuGroupID],
                   let group = store.group(for: menuGroupID) {
                    let rect = proxy[anchor]
                    let menuWidth: CGFloat = 246
                    let menuHeight: CGFloat = 128
                    let x = min(max(rect.midX, menuWidth / 2 + 18), proxy.size.width - menuWidth / 2 - 18)
                    let y = rect.maxY + menuHeight / 2 + 10

                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                activeGroupMenuID = nil
                            }

                        GroupContextMenuView(
                            group: group,
                            onRename: {
                                editingGroupID = group.id
                                editingGroupTitle = group.title
                                store.selectedSourceID = group.id
                                activeGroupMenuID = nil
                            },
                            onShare: {
                                sharePinboard(for: group)
                                activeGroupMenuID = nil
                            },
                            onDelete: {
                                deleteGroup(group)
                                activeGroupMenuID = nil
                            },
                            onColorChange: { token in
                                store.updateGroupColor(id: group.id, token: token)
                            },
                            colorResolver: color
                        )
                        .frame(width: menuWidth, height: menuHeight)
                        .position(x: x, y: y)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panelShell: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.10, blue: 0.12),
                        Color(red: 0.12, green: 0.13, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
            .shadow(color: .black.opacity(0.45), radius: 26, y: 8)
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            circleButton(systemName: "arrow.clockwise") {
                store.captureCurrentClipboard()
            }

            Spacer(minLength: 0)

            HStack(spacing: 22) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))

                SelectedClipboardChip(
                    count: store.items.count,
                    isSelected: store.selectedSourceID == "all"
                ) {
                    store.selectedSourceID = "all"
                }

                ForEach(store.groups, id: \.id) { group in
                    EditableGroupTab(
                        id: group.id,
                        title: group.title,
                        color: color(for: group.colorToken),
                        isSelected: store.selectedSourceID == group.id,
                        isEditing: editingGroupID == group.id,
                        draftTitle: $editingGroupTitle,
                        onSubmit: {
                            store.renameGroup(id: group.id, to: editingGroupTitle)
                            editingGroupID = nil
                        },
                        onSecondaryClick: {
                            activeGroupMenuID = group.id
                        }
                    ) {
                        activeGroupMenuID = nil
                        store.selectedSourceID = group.id
                    }
                }

                Button {
                    store.createGroup()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.88))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            circleButton(systemName: "ellipsis") {
                store.clearAll()
            }
        }
        .padding(.horizontal, 8)
    }

    private var cardsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 26) {
                ForEach(store.visibleItems) { item in
                    ClipboardCard(item: item)
                        .environmentObject(store)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
                Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func color(for token: GroupColorToken) -> Color {
        gradient(for: token).start
    }

    private func colorName(for token: GroupColorToken) -> String {
        switch token {
        case .red:
            return "Red"
        case .orange:
            return "Orange"
        case .yellow:
            return "Yellow"
        case .gray:
            return "Gray"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .purple:
            return "Purple"
        case .pink:
            return "Pink"
        }
    }

    private func gradient(for token: GroupColorToken) -> (start: Color, end: Color) {
        switch token {
        case .red:
            return (
                Color(red: 0.95, green: 0.31, blue: 0.36),
                Color(red: 0.86, green: 0.18, blue: 0.25)
            )
        case .orange:
            return (
                Color(red: 1.00, green: 0.67, blue: 0.25),
                Color(red: 0.96, green: 0.50, blue: 0.15)
            )
        case .yellow:
            return (
                Color(red: 0.98, green: 0.78, blue: 0.15),
                Color(red: 0.91, green: 0.63, blue: 0.07)
            )
        case .gray:
            return (
                Color(red: 0.63, green: 0.64, blue: 0.69),
                Color(red: 0.52, green: 0.53, blue: 0.58)
            )
        case .green:
            return (
                Color(red: 0.18, green: 0.80, blue: 0.68),
                Color(red: 0.12, green: 0.70, blue: 0.60)
            )
        case .blue:
            return (
                Color(red: 0.17, green: 0.58, blue: 0.98),
                Color(red: 0.10, green: 0.44, blue: 0.89)
            )
        case .purple:
            return (
                Color(red: 0.78, green: 0.27, blue: 0.93),
                Color(red: 0.63, green: 0.18, blue: 0.78)
            )
        case .pink:
            return (
                Color(red: 1.00, green: 0.31, blue: 0.53),
                Color(red: 0.95, green: 0.20, blue: 0.38)
            )
        }
    }

    private func sharePinboard(for group: ClipboardGroup) {
        let export = store.items
            .filter { $0.groupID == group.id }
            .map { item -> String in
                switch item.kind {
                case .text:
                    return item.textPreview
                case .image:
                    return "[Image \(item.footerLabel)]"
                }
            }
            .joined(separator: "\n\n")

        let output = export.isEmpty ? group.title : "# \(group.title)\n\n\(export)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)
    }

    private func deleteGroup(_ group: ClipboardGroup) {
        let alert = NSAlert()
        alert.messageText = "Delete Group?"
        alert.informativeText = "Items in this group will be moved back to Clipboard."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            store.deleteGroup(id: group.id)
        }
    }
}

private struct ClipboardCard: View {
    @EnvironmentObject private var store: ClipboardStore
    let item: ClipboardItem

    var body: some View {
        Button {
            store.copy(item)
        } label: {
            VStack(spacing: 0) {
                header
                cardBody
            }
            .frame(width: 248, height: 252)
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: .black.opacity(0.34), radius: 18, y: 12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Again") {
                store.copy(item)
            }
            Button(item.isPinned ? "Unpin" : "Pin") {
                store.togglePin(item)
            }
            Menu("Move To Group") {
                Button("Clipboard") {
                    store.move(item, toGroupID: nil)
                }

                if store.groups.isEmpty {
                    Button("No Groups Yet") {}
                        .disabled(true)
                } else {
                    ForEach(store.groups, id: \.id) { group in
                        Button(group.title) {
                            store.move(item, toGroupID: group.id)
                        }
                    }
                }
            }
            Divider()
            Button("Delete") {
                store.remove(item)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.cardTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(headerTint)
                Text(item.relativeTimestamp)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(headerTint.opacity(0.82))
            }

            Spacer(minLength: 0)

            AppIconBadge(item: item)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(height: 54, alignment: .top)
        .background(
            LinearGradient(
                colors: [headerColors.start, headerColors.end],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var headerColors: (start: Color, end: Color) {
        if let group = store.group(for: item.groupID) {
            switch group.colorToken {
            case .red:
                return (
                    Color(red: 0.95, green: 0.31, blue: 0.36),
                    Color(red: 0.86, green: 0.18, blue: 0.25)
                )
            case .orange:
                return (
                    Color(red: 1.00, green: 0.67, blue: 0.25),
                    Color(red: 0.96, green: 0.50, blue: 0.15)
                )
            case .yellow:
                return (
                    Color(red: 0.98, green: 0.78, blue: 0.15),
                    Color(red: 0.91, green: 0.63, blue: 0.07)
                )
            case .gray:
                return (
                    Color(red: 0.63, green: 0.64, blue: 0.69),
                    Color(red: 0.52, green: 0.53, blue: 0.58)
                )
            case .green:
                return (
                    Color(red: 0.18, green: 0.80, blue: 0.68),
                    Color(red: 0.12, green: 0.70, blue: 0.60)
                )
            case .blue:
                return (
                    Color(red: 0.17, green: 0.58, blue: 0.98),
                    Color(red: 0.10, green: 0.44, blue: 0.89)
                )
            case .purple:
                return (
                    Color(red: 0.78, green: 0.27, blue: 0.93),
                    Color(red: 0.63, green: 0.18, blue: 0.78)
                )
            case .pink:
                return (
                    Color(red: 1.00, green: 0.31, blue: 0.53),
                    Color(red: 0.95, green: 0.20, blue: 0.38)
                )
            }
        }
        return (item.sourceStyle.accent, item.sourceStyle.secondaryAccent)
    }

    private var headerTint: Color {
        if store.group(for: item.groupID) != nil {
            return .white
        }
        return item.sourceStyle.tint
    }

    @ViewBuilder
    private var cardBody: some View {
        switch item.kind {
        case .text:
            textBody
        case .image:
            imageBody
        }
    }

    private var textBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.textPreview)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .lineLimit(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(item.footerLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.54))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    private var imageBody: some View {
        ZStack(alignment: .bottom) {
            CheckerboardBackground()

            if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 208, maxHeight: 108)
                    .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
            }

            Text(item.footerLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.54))
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
    }

    private var borderColor: Color {
        if store.lastCopiedItemID == item.id {
            return Color(red: 0.10, green: 0.49, blue: 1.0)
        }
        return Color.white.opacity(0.05)
    }

    private var borderWidth: CGFloat {
        store.lastCopiedItemID == item.id ? 4 : 1
    }
}

private struct SelectedClipboardChip: View {
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ToolbarChip(isSelected: isSelected, action: action) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 10, weight: .semibold))
            Text("Clipboard")
                .font(.system(size: 11, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(isSelected ? 0.68 : 0.56))
        }
    }
}

private struct EditableGroupTab: View {
    let id: String
    let title: String
    let color: Color
    let isSelected: Bool
    let isEditing: Bool
    @Binding var draftTitle: String
    let onSubmit: () -> Void
    let onSecondaryClick: () -> Void
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                TextField("", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .frame(minWidth: 52, maxWidth: 110)
                    .focused($isFocused)
                    .onSubmit(onSubmit)
                    .onAppear {
                        DispatchQueue.main.async {
                            isFocused = true
                        }
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            onSubmit()
                        }
                    }
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
            .zIndex(2)
            .anchorPreference(key: GroupFramePreferenceKey.self, value: .bounds) { [id: $0] }
        } else {
            InteractiveGroupChip(
                id: id,
                isSelected: isSelected,
                action: action,
                secondaryAction: onSecondaryClick
            ) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .anchorPreference(key: GroupFramePreferenceKey.self, value: .bounds) { [id: $0] }
        }
    }
}

private struct GroupContextMenuView: View {
    let group: ClipboardGroup
    let onRename: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let onColorChange: (GroupColorToken) -> Void
    let colorResolver: (GroupColorToken) -> Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionRow("pencil", "Rename", onRename)
            actionRow("square.and.arrow.up", "Share Pinboard", onShare)
            actionRow("trash", "Delete...", onDelete)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            HStack(spacing: 12) {
                ForEach(GroupColorToken.allCases, id: \.self) { token in
                    Button {
                        onColorChange(token)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(colorResolver(token))
                                .frame(width: 17, height: 17)

                            if group.colorToken == token {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.88), lineWidth: 2)
                                    .frame(width: 23, height: 23)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.14, blue: 0.16).opacity(0.97),
                            Color(red: 0.11, green: 0.12, blue: 0.15).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
    }

    private func actionRow(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 16)
            .frame(height: 28)
        }
        .buttonStyle(.plain)
    }
}

private struct ToolbarChip<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            ToolbarChipBody(isSelected: isSelected) {
                content
            }
        }
        .buttonStyle(.plain)
        .zIndex(isSelected ? 1 : 0)
    }
}

private struct ToolbarChipBody<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .foregroundStyle(Color.white.opacity(isSelected ? 0.96 : 0.74))
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.10 : 0.00))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(isSelected ? 0.16 : 0.00), lineWidth: 1)
                )
        )
    }
}

private struct InteractiveGroupChip<Content: View>: NSViewRepresentable {
    let id: String
    let isSelected: Bool
    let action: () -> Void
    let secondaryAction: () -> Void
    let content: Content

    init(
        id: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.isSelected = isSelected
        self.action = action
        self.secondaryAction = secondaryAction
        self.content = content()
    }

    func makeNSView(context: Context) -> InteractiveGroupHostView {
        let view = InteractiveGroupHostView()
        view.onPrimaryClick = action
        view.onSecondaryClick = secondaryAction
        return view
    }

    func updateNSView(_ nsView: InteractiveGroupHostView, context: Context) {
        nsView.onPrimaryClick = action
        nsView.onSecondaryClick = secondaryAction
        nsView.hostingView.rootView = AnyView(
            ToolbarChipBody(isSelected: isSelected) {
                content
            }
        )
    }
}

private final class InteractiveGroupHostView: NSView {
    let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    var onPrimaryClick: () -> Void = {}
    var onSecondaryClick: () -> Void = {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        onPrimaryClick()
    }

    override func rightMouseDown(with event: NSEvent) {
        onSecondaryClick()
    }
}

private struct GroupFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct AppIconBadge: View {
    let item: ClipboardItem

    var body: some View {
        if let icon = item.appIcon() {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 52, height: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.38), lineWidth: 1)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                Image(systemName: item.sourceStyle.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(item.sourceStyle.accent)
            }
            .frame(width: 52, height: 52)
        }
    }
}

private struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 12
            let rows = Int(ceil(size.height / square))
            let columns = Int(ceil(size.width / square))

            for row in 0..<rows {
                for column in 0..<columns {
                    let rect = CGRect(
                        x: CGFloat(column) * square,
                        y: CGFloat(row) * square,
                        width: square,
                        height: square
                    )
                    let isDark = (row + column).isMultiple(of: 2)
                    context.fill(
                        Path(rect),
                        with: .color(isDark ? Color(red: 0.13, green: 0.13, blue: 0.14) : Color(red: 0.17, green: 0.17, blue: 0.18))
                    )
                }
            }
        }
    }
}
