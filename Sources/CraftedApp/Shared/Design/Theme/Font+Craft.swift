import SwiftUI
import AppKit

// The same three faces as Ambient (`Design.swift`, `Paper+Type.swift`): the system serif
// (New York) for what is read as prose, the system sans for chrome and labels, and the
// system mono for code. No bundled fonts, in either app.

extension Font {
    static func craftSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func craftSerif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let font = Font.system(size: size, weight: weight, design: .serif)
        return italic ? font.italic() : font
    }

    /// Code, paths, tool output, diffs and the composer.
    static func craftMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// An SF Symbol at the size of the text it sits beside.
    static func craftGlyph(_ glyph: CraftGlyph, weight: Font.Weight = .regular) -> Font {
        .system(size: glyph.size, weight: weight)
    }
}
