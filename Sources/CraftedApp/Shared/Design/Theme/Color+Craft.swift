import SwiftUI
import AppKit

// Graphite surfaces under dark, cream paper under light; the tint is platinum on one and ink on
// the other. Each token is `NSColor+Craft`'s pair, so it resolves against the view it is drawn in.

extension Color {
    /// The tint: links, the selection, a prominent button's fill, the caret.
    static let craftTint = Color(nsColor: .craftTint)

    static let craftBG = Color(nsColor: .craftBG)
    static let craftRaised = Color(nsColor: .craftRaised)
    static let craftWell = Color(nsColor: .craftWell)
    static let craftInk = Color(nsColor: .craftInk)
    /// The ink scale: one step per job, so no view picks its own opacity.
    /// Secondary text: captions, counts, a row's second line.
    static var craftInkDim: Color { Color.craftInk.opacity(0.55) }
    /// Text that leads but steps back: a card's prose under its heading, a chip's label.
    static var craftInkSoft: Color { Color.craftInk.opacity(0.8) }
    /// Section headers, thinking, quiet marks.
    static var craftInkMuted: Color { Color.craftInk.opacity(0.45) }
    /// The faintest text: field keys, separators, placeholders.
    static let craftInkFaint = Color(nsColor: .craftInkFaint)
    static var craftBorder: Color { Color.craftTint.opacity(0.14) }
    static let craftError = Color(nsColor: .craftError)
}

extension Color {
    static let craftSuccess = Color(nsColor: .craftSuccess)
    static let craftWarning = Color(nsColor: .craftWarning)
    /// What the person has (an agent in their library), as a wash under its words.
    static var craftSuccessFill: Color { craftSuccess.opacity(0.14) }
}

extension Color {
    /// Fills on the page, faintest first: a resting row, a resting control, a hovered one.
    static var craftFillTrace: Color { Color.craftInk.opacity(0.04) }
    static var craftFill: Color { Color.craftInk.opacity(0.07) }
    static var craftFillHover: Color { Color.craftInk.opacity(0.12) }
    /// The selected row's fill.
    static var craftFillSelected: Color { Color.craftTint.opacity(0.14) }
    /// The one shadow under a raised surface.
    static let craftShadow = Color(nsColor: .craftShadow)
}
