//  WHAT: Which engine draws a page: the style's own rules for the format, weighted by how well each fits what the page
//        says. A page of a few big lines is a hero; a picture and words a split; long text a column; many short
//        things a grid.
//  PIN:  THE STYLE DECIDES, THE CONTENT TIPS. Only engines the style draws this format with are in the running (its
//        default when it names none); a page's content only weighs between them. Deterministic: the same page in the
//        same style draws the same way every time.

import Foundation

public enum ArchetypeChooser {
    public static func choose(_ page: PiecePage, index: Int, format: PieceFormat, style: AtelierStyle) -> (Archetype, StyleLayout.Rule?) {
        let rules = style.layout.rules(for: format)
        guard !rules.isEmpty else { return (format.defaultArchetype, nil) }
        if let asked = page.archetype, let rule = rules.first(where: { $0.engine == asked }) { return (asked, rule) }
        var best: (score: Double, rule: StyleLayout.Rule)?
        for rule in rules {
            // A rule that names this format is the designer's own choice for it, and outweighs one for every format.
            let specific = rule.for.isEmpty ? 1.0 : 1.25
            let score = rule.weight * specific * fit(rule.engine, page, index: index, format: format)
            if best == nil || score > best!.score + 1e-9 { best = (score, rule) }
        }
        return (best!.rule.engine, best!.rule)
    }

    /// How well an engine suits a page's content, 0.2 to 1.
    static func fit(_ engine: Archetype, _ page: PiecePage, index: Int, format: PieceFormat) -> Double {
        let body = page.blocks.filter { !$0.kind.isHead && $0.kind != .footer && $0.kind != .divider }
        let cells = body.filter { [.stat, .list, .steps, .quote, .callout, .details, .table, .image].contains($0.kind) }.count
        let characters = body.map(\.words.count).reduce(0, +)
        let picture = page.first(.image) != nil
        switch engine {
        case .hero:
            if index == 0 && format.maxPages > 1 { return 1 }
            return body.count <= 3 && characters < 420 ? 1 : body.count <= 5 ? 0.6 : 0.3
        case .split:
            return picture ? 1 : (format.isLandscape ? 0.7 : 0.45)
        case .column:
            return characters > 600 && cells <= 2 ? 1 : characters > 300 ? 0.7 : 0.4
        case .grid:
            return cells >= 4 ? 1 : cells >= 2 ? 0.6 : 0.25
        }
    }
}
