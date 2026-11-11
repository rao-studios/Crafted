import SwiftUI
import AppKit

/// Text roles, one per job. A view picks a role, never a size; a weight a role does not carry is
/// added with `.fontWeight(_:)` after it.
enum CraftType {
    /// The assistant's prose.
    case reply
    /// What the person wrote.
    case user
    /// Sheet and empty-state headers.
    case title
    /// A Settings page's title.
    case pageTitle
    /// A number read at a glance: a stat's value, a plan's title in the strip.
    case figure
    /// The selected item's name over a detail pane.
    case detailTitle
    /// A card's or a sheet's own name.
    case heading
    /// Sans body: card text, sidebar values.
    case body
    /// Sans labels: tool names, buttons, tabs, sidebar rows.
    case label
    /// A label that leads its row.
    case labelStrong
    /// Sans captions: status lines, secondary facts.
    case caption
    /// A caption that leads its row: chips, pills, short states.
    case captionStrong
    /// The smallest prose: hints under a control, meter legends.
    case fine
    /// SMALL CAPS SECTION HEADERS.
    case section
    /// TINY CAPSULE TAGS.
    case badge
    /// A window's own name in its header bar.
    case windowTitle
    /// Names that are keys: framework ids, model ids, agent ids, paths in a list.
    case identifier
    /// Code, paths, diffs.
    case code
    /// Code in chrome: line ranges, byte counts.
    case codeSmall
    /// The smallest code: timings and counts beside a code line.
    case codeTiny

    /// The three faces (`Font+Craft`).
    enum Face { case serif, sans, mono }

    /// Face, size, weight and slant, in one place for every role.
    var spec: (face: Face, size: CGFloat, weight: Font.Weight, italic: Bool) {
        switch self {
        case .reply: return (.serif, 15, .regular, false)
        case .user: return (.serif, 14, .light, false)
        case .title: return (.serif, 18, .light, true)
        case .pageTitle: return (.serif, 22, .light, true)
        case .figure: return (.serif, 16, .medium, false)
        case .detailTitle: return (.sans, 15, .medium, false)
        case .heading: return (.sans, 13, .medium, false)
        case .body: return (.sans, 13, .regular, false)
        case .label: return (.sans, 12, .regular, false)
        case .labelStrong: return (.sans, 12, .medium, false)
        case .caption: return (.sans, 11, .regular, false)
        case .captionStrong: return (.sans, 11, .medium, false)
        case .fine: return (.sans, 10, .regular, false)
        case .section: return (.sans, 10, .semibold, false)
        case .badge: return (.sans, 9, .semibold, false)
        case .windowTitle: return (.mono, 13, .semibold, false)
        case .identifier: return (.mono, 11, .regular, false)
        case .code: return (.mono, 12, .regular, false)
        case .codeSmall: return (.mono, 10, .regular, false)
        case .codeTiny: return (.mono, 9, .regular, false)
        }
    }

    /// The role's point size, for what takes a size rather than a font (the markdown theme, AppKit).
    var size: CGFloat { spec.size }

    var font: Font {
        let spec = spec
        switch spec.face {
        case .serif: return .craftSerif(spec.size, weight: spec.weight, italic: spec.italic)
        case .sans: return .craftSans(spec.size, weight: spec.weight)
        case .mono: return .craftMono(spec.size, weight: spec.weight)
        }
    }

    /// The role at another weight: the conditional weights (a selected tab, a bold token).
    func font(weight: Font.Weight) -> Font {
        switch spec.face {
        case .serif: return .craftSerif(spec.size, weight: weight, italic: spec.italic)
        case .sans: return .craftSans(spec.size, weight: weight)
        case .mono: return .craftMono(spec.size, weight: weight)
        }
    }

    var kerning: CGFloat {
        switch self {
        case .reply, .user: return 0.2
        case .section, .badge: return 0.8
        default: return 0
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .reply: return 5
        case .user: return 4
        case .code: return 2
        default: return 0
        }
    }
}
