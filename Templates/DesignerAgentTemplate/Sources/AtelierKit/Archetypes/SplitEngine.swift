import Foundation

/// A split: two panels. The picture (or, with none, a colour field in the style's accent or gradient holding the
/// logo, kicker and a figure) on one side, the words on the other; side by side on a wide page, one above the other on
/// a tall one. The media panel runs to the page's edge; the words keep the margin.
enum SplitEngine: LayoutEngine {
    static func body(_ context: EngineContext) -> String {
        let blocks = context.numbered
        let side = mediaSide(context)
        var media: [(Int, PieceBlock)] = []
        if let picture = blocks.first(where: { $0.1.kind == .image }) {
            media = [picture]
        } else {
            let logo = blocks.first { $0.1.kind == .logo }
            let kicker = blocks.first { $0.1.kind == .kicker }
            let stat = blocks.first { $0.1.kind == .stat }
            media = [logo, kicker, stat].compactMap { $0 }
        }
        let text = blocks.filter { item in !media.contains { $0.0 == item.0 } }
        let panel = media.contains { $0.1.kind == .image } ? "" : " panel"
        let mediaZone = media.isEmpty
            ? "<div class=\"zone z-media panel\" data-zone=\"media\" data-page=\"\(context.index + 1)\" style=\"--fit:1\"></div>"
            : zone("media", media, context, extra: panel)
        return "<div class=\"split side-\(side)\">" + mediaZone + zone("text", text, context) + "</div>"
    }

    /// Where the media panel goes: the style's rule, else left on a wide page and top on a tall one.
    static func mediaSide(_ context: EngineContext) -> String {
        let wide = context.size.width >= context.size.height
        switch context.imageSide {
        case "right": return wide ? "right" : "top"
        case "left": return wide ? "left" : "top"
        case "bottom", "top", "background": return wide ? "left" : "top"
        default: return wide ? "left" : "top"
        }
    }

    static let css = """
    .page.e-split { padding: 0; }
    .e-split .split { flex: 1 1 auto; display: flex; min-height: 0; }
    .e-split .split.side-left { flex-direction: row; } .e-split .split.side-right { flex-direction: row-reverse; }
    .e-split .split.side-top { flex-direction: column; }
    .e-split .z-media { flex: 0 0 42%; padding: 0; overflow: hidden; }
    .e-split .split.side-top .z-media { flex-basis: 40%; }
    .e-split .z-media .b-image { height: 100%; margin: 0; }
    .e-split .z-media .b-image .ph { border-radius: 0; }
    .e-split .z-media .b-image figcaption { display: none; }
    .e-split .z-media.panel { background: var(--panel); color: var(--accent-ink); padding: var(--margin); justify-content: space-between; }
    .e-split .z-media.panel .b-kicker, .e-split .z-media.panel .b-stat .fig, .e-split .z-media.panel .b-stat .cap, .e-split .z-media.panel .b-logo { color: var(--accent-ink); }
    .e-split .z-text { flex: 1 1 0; padding: var(--margin); justify-content: center; }
    .e-split .z-text .b-footer { margin-top: auto; }
    """
}
