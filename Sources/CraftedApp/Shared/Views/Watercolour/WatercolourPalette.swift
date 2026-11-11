//  WHAT: The watercolour's own colours: Rao's paper and ink, and the three pigments the blooms are mixed from.
//  PIN:  THE SITE'S VALUES (craft.rao.nyc, app/(store)/_styles/tokens.css and the blooms' tones). Kept here rather than
//        in the app's theme so the paintings never move when the chrome's palette does: the art is light-only.

import SwiftUI

enum WatercolourPalette {
    /// #FDFBF4, the leaf every painting sits on.
    static let paper = Color(red: 0xFD / 255, green: 0xFB / 255, blue: 0xF4 / 255)
    /// #37352F, the ink for words on paper.
    static let ink = Color(red: 0x37 / 255, green: 0x35 / 255, blue: 0x2F / 255)
    /// #AE9060, the brass the icon's knots are tied in.
    static let brass = Color(red: 0xAE / 255, green: 0x90 / 255, blue: 0x60 / 255)
    /// #9FB3C6, the sky's blue.
    static let sky = Color(red: 0x9F / 255, green: 0xB3 / 255, blue: 0xC6 / 255)
    /// #B4614A, the rooftops' clay.
    static let clay = Color(red: 0xB4 / 255, green: 0x61 / 255, blue: 0x4A / 255)
}
