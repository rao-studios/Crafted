import SwiftUI

/// The tint for the action a card is asking for, a quiet fill for the rest.
struct CraftButtonStyle: ButtonStyle {
    enum Kind { case prominent, quiet, destructive }
    var kind: Kind = .prominent
    /// A set height, for a button in a row of tags and chips that height (`CraftLayout.AgentStore.control`); nil, the
    /// control's own padding.
    var height: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, kind: kind, height: height)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let kind: Kind
        let height: CGFloat?
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .craftType(.labelStrong)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, CraftInset.control.leading)
                .padding(.vertical, height == nil ? CraftInset.control.top : 0)
                .frame(height: height)
                .foregroundStyle(foreground)
                .background(
                    RoundedRectangle(cornerRadius: CraftRadius.control, style: .continuous)
                        .fill(fill)
                        .opacity(configuration.isPressed ? 0.75 : 1))
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }

        private var foreground: Color {
            switch kind {
            case .prominent: return .craftBG
            case .quiet: return .craftInk
            case .destructive: return .craftError
            }
        }

        private var fill: Color {
            switch kind {
            case .prominent: return hovering ? Color.craftTint.opacity(0.88) : .craftTint
            case .quiet: return hovering ? Color.craftFillHover : Color.craftFill
            case .destructive: return Color.craftError.opacity(hovering ? 0.22 : 0.14)
            }
        }
    }
}
