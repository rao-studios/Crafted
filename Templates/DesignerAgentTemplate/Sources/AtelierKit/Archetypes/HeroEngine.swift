import Foundation

/// A hero: one large headline owns the page. The mark or logo at the top, a picture as a band when there is one, the
/// kicker, headline, subhead and lead together where the style puts its headline (top, middle, bottom), the rest
/// quieter under it, the footer last.
enum HeroEngine: LayoutEngine {
    static func body(_ context: EngineContext) -> String {
        let blocks = context.numbered
        let firstImage = blocks.first { $0.1.kind == .image }
        let top = blocks.filter { $0.1.kind == .logo }
        let hero = blocks.filter { [.kicker, .headline, .subhead, .lead].contains($0.1.kind) }
        let foot = blocks.filter { $0.1.kind == .footer }
        let rest = blocks.filter { item in
            !top.contains { $0.0 == item.0 } && !hero.contains { $0.0 == item.0 } && !foot.contains { $0.0 == item.0 } && item.0 != firstImage?.0
        }
        let position = context.headlinePosition
        let wide = context.size.width > context.size.height * 1.15 && rest.count >= 2
        return zone("top", top, context)
            + (firstImage.map { zone("media", [$0], context) } ?? "")
            + zone("hero", hero, context, extra: " at-\(position)")
            + zone("rest", rest, context, extra: wide ? " across" : "")
            + zone("foot", foot, context)
    }

    static let css = """
    .e-hero .z-top { flex: none; flex-direction: row; align-items: center; justify-content: space-between; }
    .e-hero .z-media { flex: 1 1 38%; }
    .e-hero .z-media .b-image { height: 100%; }
    .e-hero .z-hero { flex: 1 1 auto; justify-content: flex-end; }
    .e-hero .z-hero.at-top { justify-content: flex-start; } .e-hero .z-hero.at-middle { justify-content: center; }
    .e-hero .z-hero .b-headline { font-size: calc(var(--fit) * var(--s-display)); }
    .e-hero .z-rest { flex: 0 1 auto; }
    .e-hero .z-rest.across { display: grid; grid-template-columns: repeat(auto-fit, minmax(28%, 1fr)); column-gap: var(--gutter); row-gap: calc(var(--gap) * var(--fit)); align-items: start; }
    .e-hero .z-foot { flex: none; }
    """
}
