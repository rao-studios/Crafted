//  WHAT: Crafted's glyph (Resources/glyph.svg, the embroidered line drawing the icon stitches), in the caller's
//        foreground style. While `animated` it breathes and a light sweeps down it, as Craft's CraftHandMark does,
//        so a long stage still looks alive when the words beside it have not changed for a minute.
//  IN:   The size (the glyph's box is square) and whether it moves.
//  OUT:  The mark, or an SF Symbol folder when the glyph is missing.
//  PIN:  The line is redrawn for the size (WatercolourArt.glyph): glyph.svg draws at 1.7 units of 320, a hairline
//        under a few hundred points, so the mark asks for about 1.15 pt of line whatever its size.
//  PIN:  Reduce Motion holds it still and whole.

import SwiftUI

struct CraftedMark: View {
    private let size: CGFloat
    private let animated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var sweeping = false

    init(size: CGFloat, animated: Bool = false) {
        self.size = size
        self.animated = animated
    }

    private var isAnimating: Bool { animated && !reduceMotion }

    /// About 1.15 pt of line at any size, never thinner than the drawing's own.
    private var stroke: Double { max(1.7, 1.15 * 320 / Double(max(size, 1))) }

    var body: some View {
        glyph
            .frame(width: size, height: size)
            .opacity(isAnimating && !breathing ? 0.45 : 1)
            .animation(isAnimating ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: breathing)
            .overlay { if isAnimating { sweep } }
            .onAppear { start(isAnimating) }
            .onChange(of: isAnimating) { _, on in start(on) }
            .accessibilityLabel("Crafted")
    }

    private var glyph: some View {
        Group {
            if let image = WatercolourArt.glyph(stroke: stroke) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "folder")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.ultraLight)
            }
        }
    }

    /// A band of the full ink travelling down the glyph while the glyph itself breathes.
    private var sweep: some View {
        Rectangle()
            .fill(.foreground)
            .mask {
                LinearGradient(colors: [.clear, .black.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(width: size, height: size)
                    .offset(y: sweeping ? size : -size)
                    .animation(.linear(duration: 1.8).repeatForever(autoreverses: false), value: sweeping)
            }
            .mask(glyph.frame(width: size, height: size))
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }

    private func start(_ on: Bool) {
        breathing = on
        sweeping = on
    }
}
