import SwiftUI

/// One entry in a sidebar: its symbol, its name and, when it has them, a count and a mark (where it is kept). The tint under the selection while the
/// window is key, a quieter fill when it is not, a trace under the pointer. Settings and the project sheet draw theirs
/// with it.
struct SidebarRow: View {
    let symbol: String
    let title: String
    var count: Int?
    /// A trailing symbol, its meaning in `markHelp`.
    var mark: String?
    var markHelp: String?
    let selected: Bool
    var identifier: String?
    let select: () -> Void
    @Environment(\.controlActiveState) private var activeState
    @State private var hovered = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: .layer2) {
                Image(systemName: symbol)
                    .font(.craftGlyph(.heading))
                    .frame(width: Self.glyphColumn)
                    .foregroundStyle(selected ? Color.craftInkSoft : Color.craftInkDim)
                Text(title)
                    .font(CraftType.body.font(weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? Color.craftInk : Color.craftInkSoft)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let count {
                    Text(count.formatted()).craftType(.caption).monospacedDigit().foregroundStyle(Color.craftInkDim)
                }
                if let mark {
                    Image(systemName: mark).font(.craftGlyph(.small)).foregroundStyle(Color.craftInkMuted)
                        .frame(width: Self.glyphColumn).help(markHelp ?? "")
                }
            }
            .padding(.horizontal, .layer2)
            .frame(height: Self.height)
            .background(RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous).fill(fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier ?? title)
    }

    private var fill: Color {
        if selected { return activeState == .key ? Color.craftFillSelected : Color.craftFill }
        return hovered ? Color.craftFillTrace : .clear
    }

    /// The row's height and its symbol's column, as a macOS settings sidebar draws them.
    static let height: CGFloat = 28
    static let glyphColumn: CGFloat = 18
}
