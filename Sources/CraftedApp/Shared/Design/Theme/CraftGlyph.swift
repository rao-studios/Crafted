import SwiftUI
import AppKit

/// SF Symbol sizes, named for the text role a glyph sits beside: a glyph in a caption row is `.caption`.
enum CraftGlyph {
    /// Status marks inside a dot or a gutter.
    case fine
    /// Beside code-tiny and fine text; a chip's icon.
    case small
    /// Beside a caption.
    case caption
    /// Beside a label: sidebar and toolbar icons.
    case label
    /// Beside body text.
    case body
    /// Beside a heading.
    case heading
    /// An icon button's glyph on its own, inside the composer's field (Capture).
    case control
    /// A step's one mark, on its own above a page title.
    case display

    var size: CGFloat {
        switch self {
        case .fine: return 8
        case .small: return 9
        case .caption: return 10
        case .label: return 11
        case .body: return 12
        case .heading: return 13
        case .control: return 15
        case .display: return 40
        }
    }
}
