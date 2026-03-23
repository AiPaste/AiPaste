import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ClipboardStore

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
                    GroupTab(
                        title: group.title,
                        color: color(for: group.colorToken),
                        isSelected: store.selectedSourceID == group.id
                    ) {
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
        switch token {
        case .red:
            return Color(red: 1.00, green: 0.27, blue: 0.31)
        case .orange:
            return Color(red: 1.00, green: 0.63, blue: 0.19)
        case .gray:
            return Color(red: 0.75, green: 0.75, blue: 0.79)
        case .green:
            return Color(red: 0.20, green: 0.83, blue: 0.36)
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
                    .foregroundStyle(item.sourceStyle.tint)
                Text(item.relativeTimestamp)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(item.sourceStyle.tint.opacity(0.82))
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
                colors: [item.sourceStyle.accent, item.sourceStyle.secondaryAccent],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
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

private struct GroupTab: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ToolbarChip(isSelected: isSelected, action: action) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
    }
}

private struct ToolbarChip<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
        .zIndex(isSelected ? 1 : 0)
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
