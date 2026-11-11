import SwiftUI
import AppKit

// Every colour is written once, here, as a pair: graphite under dark, cream paper under light.
// Each resolves when it is drawn, so a window follows the appearance it is in, and
// `Color+Craft` builds the SwiftUI tokens from these.

extension NSColor {
    /// The tint: platinum (#E5E4E2) on graphite, the embroidered hand's ink on paper.
    static let craftTint = pair(srgb(229, 228, 226), srgb(61, 59, 54))
    static let craftBG = pair(srgb(22, 22, 24), srgb(244, 241, 232))
    /// Cards and the sidebar: lifted off graphite; on paper a lighter sheet, so `craftBG` wells still sink.
    static let craftRaised = pair(srgb(31, 31, 34), srgb(251, 249, 244))
    /// The well under a picture the canvas shows: below the page in both appearances, so a transparent plate's edge
    /// still reads against it.
    static let craftWell = pair(srgb(14, 14, 16), srgb(232, 229, 220))
    /// The composer draws its text in AppKit, in the same ink.
    static let craftInk = pair(srgb(236, 235, 233), srgb(42, 40, 36))
    /// `Color.craftInkFaint`'s ink, as one pair: the placeholder.
    static let craftInkFaint = pair(srgb(236, 235, 233, 0.35), srgb(42, 40, 36, 0.35))
    /// The status hues, deepened on paper so they hold as text.
    static let craftError = pair(srgb(214, 96, 96), srgb(176, 68, 63))
    static let craftSuccess = pair(srgb(126, 190, 140), srgb(62, 123, 76))
    static let craftWarning = pair(srgb(214, 170, 96), srgb(150, 102, 28))
    /// The one shadow under a raised surface: black on graphite, a breath of ink on paper.
    static let craftShadow = pair(srgb(0, 0, 0, 0.25), srgb(42, 40, 36, 0.12))

    /// One token: `dark` wherever the drawing appearance is dark, `light` everywhere else.
    private static func pair(_ dark: NSColor, _ light: NSColor) -> NSColor {
        NSColor(name: nil) { $0.isDark ? dark : light }
    }

    private static func srgb(_ red: Int, _ green: Int, _ blue: Int, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
    }
}
