import Foundation

/// A column: a head (kicker, logo, headline, subhead, lead) across the page, then one reading column held to a
/// comfortable measure, the footer at the foot. For text that is read, not glanced at.
enum ColumnEngine: LayoutEngine {
    static func body(_ context: EngineContext) -> String {
        let blocks = context.numbered
        // The head is the run of opening kinds before the first block that is not one.
        let opening = blocks.prefix { $0.1.kind.isHead }
        let foot = blocks.filter { $0.1.kind == .footer }
        let body = blocks.filter { item in !opening.contains { $0.0 == item.0 } && !foot.contains { $0.0 == item.0 } }
        return zone("head", Array(opening), context) + zone("body", body, context) + zone("foot", foot, context)
    }

    static let css = """
    .e-column .z-head { flex: none; padding-bottom: calc(var(--gap) * 0.4); }
    .e-column .z-body { flex: 1 1 auto; }
    .e-column .z-body > .b-body, .e-column .z-body > .b-lead, .e-column .z-body > .b-list, .e-column .z-body > .b-steps,
    .e-column .z-body > .b-quote, .e-column .z-body > .b-callout { max-width: calc(var(--s-body) * 40); }
    .e-column .z-body > .b-image { flex: 0 1 auto; min-height: calc(var(--s-body) * 8); height: 28%; }
    .e-column .z-foot { flex: none; }
    """
}
