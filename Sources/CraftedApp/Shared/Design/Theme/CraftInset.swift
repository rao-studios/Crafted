import SwiftUI
import AppKit

/// The insets that are not one layer all round: a control's padding, a row's icon gutter.
enum CraftInset {
    /// Inside a badge's capsule.
    static let badge = EdgeInsets(top: 1, leading: 5, bottom: 1, trailing: 5)
    /// Inside a store tag: a chip's breadth, a caption's height.
    static let tag = EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
    /// Inside a chip.
    static let chip = EdgeInsets(top: 3, leading: 7, bottom: 3, trailing: 7)
    /// Inside a button or a one-line field.
    static let control = EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
    /// The leading column a row's glyph sits centred in, so the text of every row starts on one line.
    static let iconGutter: CGFloat = 16
    /// How far a card's body hangs under its title, past the title's glyph.
    static let hang: CGFloat = 22
    /// Inside a sidebar module's card, around its rows.
    static let sidebarCard = EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
}
