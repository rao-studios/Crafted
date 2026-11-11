//  WHAT: The three Lyon paintings the app shows, and what each needs beyond its pictures: where to keep the frame
//        when it crops, and where its blooms wait on the paper before the wash reaches them.
//  OUT:  ScenePainting, WatercolourArt.
//  PIN:  The names are the files' (Scripts/art/sync-watercolours.sh, Scripts/art/gen-arrival-maps.swift):
//        Watercolour/<scene>-{far,fog,near}.webp and washes/<scene>-arrival.png.
//  PIN:  Bloom places and arrival times follow Design/washes/<scene>.json: a bloom sits on a region that is painted
//        late and is gone before that region's band begins.

import SwiftUI

enum WatercolourScene: String, CaseIterable {
    /// Fourvière from the gardens: the live hero, with empty sky upper-centre and right. Generation.
    case gardens
    /// The basilica face-on under a large empty gold sky upper-left. Home's drop leaf.
    case fourviere
    /// The Saône quay, busy and horizontal. Onboarding's band, Settings' strip.
    case lyon

    /// A bloom on the unpainted paper: its pigment, where its middle sits and how wide it is (fractions of the
    /// painting), its turn, and the progress at which the wash reaches it.
    struct Bloom {
        let tone: BloomPool.Tone
        let center: UnitPoint
        let width: CGFloat
        let turn: Double
        let arrives: Double
    }

    /// The point of the painting kept in view when the frame crops it (its aspect is not the painting's 16:9).
    /// The site keeps the floor (50% 100%); a leaf here is often a wide band, so each keeps its subject instead.
    var focus: UnitPoint {
        switch self {
        case .gardens: UnitPoint(x: 0.42, y: 0.55)
        case .fourviere: UnitPoint(x: 0.58, y: 0.5)
        case .lyon: UnitPoint(x: 0.5, y: 0.62)
        }
    }

    var blooms: [Bloom] {
        switch self {
        case .gardens: [
            Bloom(tone: .brass, center: UnitPoint(x: 0.27, y: 0.36), width: 0.3, turn: 12, arrives: 0.78),
            Bloom(tone: .sky, center: UnitPoint(x: 0.22, y: 0.76), width: 0.34, turn: 168, arrives: 0.6),
            Bloom(tone: .clay, center: UnitPoint(x: 0.76, y: 0.74), width: 0.28, turn: -14, arrives: 0.34),
        ]
        case .fourviere: [
            Bloom(tone: .brass, center: UnitPoint(x: 0.76, y: 0.36), width: 0.3, turn: 192, arrives: 0.78),
            Bloom(tone: .sky, center: UnitPoint(x: 0.36, y: 0.7), width: 0.34, turn: 12, arrives: 0.6),
            Bloom(tone: .clay, center: UnitPoint(x: 0.62, y: 0.92), width: 0.26, turn: 168, arrives: 0.44),
        ]
        case .lyon: [
            Bloom(tone: .brass, center: UnitPoint(x: 0.76, y: 0.27), width: 0.26, turn: 12, arrives: 0.8),
            Bloom(tone: .sky, center: UnitPoint(x: 0.3, y: 0.9), width: 0.34, turn: -14, arrives: 0.22),
            Bloom(tone: .clay, center: UnitPoint(x: 0.62, y: 0.68), width: 0.3, turn: 192, arrives: 0.4),
        ]
        }
    }
}
