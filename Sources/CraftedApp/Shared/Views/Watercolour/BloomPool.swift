//  WHAT: A pool of pigment on the paper, as a wet brush leaves one: one of the site's three blooms (sky, brass, clay),
//        multiplied into whatever is under it.
//  IN:   The tone and an opacity. Its size is the frame it is given; it keeps its own 5:4.
//  OUT:  The bloom, or nothing when its picture is missing.
//  PIN:  Multiply, as the site lays them (washes.module.css): on paper it reads as the pigment, over a painting as a
//        glaze, never as a sticker. It needs paper or a painting under it in the same layer to blend with.

import SwiftUI

struct BloomPool: View {
    enum Tone: String, CaseIterable { case sky, brass, clay }

    private let tone: Tone
    private let opacity: Double

    init(tone: Tone, opacity: Double = 0.4) {
        self.tone = tone
        self.opacity = opacity
    }

    var body: some View {
        if let image = WatercolourArt.bloom(tone) {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .opacity(opacity)
                .blendMode(.multiply)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
