//  WHAT: A leaf of Rao's paper that a painting, and the words over it, sit on: paper, a hairline edge, the site's
//        soft leaf shadow.
//  IN:   A corner radius and the content.
//  OUT:  The content on paper, always in the light appearance: the art is light-only, so words on the leaf take
//        ink, not the window's dark-mode white.
//  PIN:  IN DARK MODE THE LEAF STAYS PAPER, shaded a little so it is not a lamp on graphite; its edge becomes a faint
//        light line and its shadow deepens. The shade covers the content too, so a painting dims with its paper.
//  PIN:  The site's numbers (tokens.css --leaf-shadow: 0 1px 2px ink/4%, 0 8px 28px ink/5%; 0.5 px ink/8% edge).

import SwiftUI

struct PaperLeaf<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    private var dark: Bool { colorScheme == .dark }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .environment(\.colorScheme, .light)
            .background { WatercolourPalette.paper }
            .overlay {
                if dark { Color.black.opacity(0.09).allowsHitTesting(false) }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(dark ? Color.white.opacity(0.07) : WatercolourPalette.ink.opacity(0.08), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            .shadow(color: (dark ? Color.black.opacity(0.3) : WatercolourPalette.ink.opacity(0.04)), radius: 1, y: 1)
            .shadow(color: (dark ? Color.black.opacity(0.35) : WatercolourPalette.ink.opacity(0.05)), radius: 14, y: 8)
    }
}
