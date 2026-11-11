import AppKit

extension NSAppearance {
    /// Graphite or paper: which of each colour pair (`NSColor+Craft`) this appearance draws.
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}
