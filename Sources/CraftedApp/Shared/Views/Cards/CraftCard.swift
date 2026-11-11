import SwiftUI

// The shared surfaces, after Ambient's `Components.swift`, in Craft's page and tint. One card,
// one label, one button family: a view composes these rather than drawing its own box.

/// The one raised surface: a card, a permission, a plan, a diff.
struct CraftCard<Content: View>: View {
    var padding: CGFloat = .layer3
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CraftRadius.card, style: .continuous)
                    .fill(Color.craftRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: CraftRadius.card, style: .continuous)
                            .strokeBorder(Color.craftBorder, lineWidth: 1)))
            .shadow(color: Color.craftShadow, radius: 6, y: 2)
    }
}
