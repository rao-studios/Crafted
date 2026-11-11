import SwiftUI

/// An inline action that reads as text: in the tint, underlined under the pointer.
///
/// PIN: FIRST TO ITS WIDTH, NEVER PAST ITS ROW. A link keeps its whole width ahead of the words beside it (its layout
/// priority) and gives way only when its row is narrower than it is: one line, cut at the end, unless its label asks for
/// more lines. It was fixed to its width, so "Download what Craft knows about SwiftData" held the cockpit at about
/// 270 pt and the whole sidebar spilled past its 240-pt minimum, cut on both edges (2026-11-05).
struct CraftLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration)
    }

    private struct Styled: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
                .foregroundStyle(isEnabled ? Color.craftTint : Color.craftInkFaint)
                .underline(hovering && isEnabled)
                .opacity(configuration.isPressed ? 0.7 : 1)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}
