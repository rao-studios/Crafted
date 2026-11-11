import SwiftUI

extension ButtonStyle where Self == CraftButtonStyle {
    static var craft: CraftButtonStyle { CraftButtonStyle(kind: .prominent) }
    static var craftQuiet: CraftButtonStyle { CraftButtonStyle(kind: .quiet) }
    static var craftDestructive: CraftButtonStyle { CraftButtonStyle(kind: .destructive) }
    /// The same, at a set height: a button in a row of tags that height.
    static func craft(height: CGFloat) -> CraftButtonStyle { CraftButtonStyle(kind: .prominent, height: height) }
    static func craftDestructive(height: CGFloat) -> CraftButtonStyle { CraftButtonStyle(kind: .destructive, height: height) }
}

extension ButtonStyle where Self == CraftLinkButtonStyle {
    static var craftLink: CraftLinkButtonStyle { CraftLinkButtonStyle() }
}
