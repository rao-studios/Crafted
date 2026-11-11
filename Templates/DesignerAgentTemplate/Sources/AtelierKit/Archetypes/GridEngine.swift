import Foundation

/// A grid: a head across the page, then the blocks as cells of a modular grid of the style's columns (two on a tall
/// page, up to four on a wide one). A long text, a table or a rule spans the row; no row is left part empty.
enum GridEngine: LayoutEngine {
    static func body(_ context: EngineContext) -> String {
        let blocks = context.numbered
        let opening = blocks.prefix { $0.1.kind.isHead }
        let foot = blocks.filter { $0.1.kind == .footer }
        let cells = blocks.filter { item in !opening.contains { $0.0 == item.0 } && !foot.contains { $0.0 == item.0 } }
        let columns = self.columns(context)
        let spans = self.spans(cells.map(\.1), columns: columns)
        let inner = zip(cells, spans).map { item, span in
            "<div class=\"cell\" style=\"grid-column: span \(span)\">" + BlockHTML.html(item.1, id: "\(context.index + 1):\(item.0 + 1)", context: context) + "</div>"
        }.joined()
        let grid = cells.isEmpty ? "" : "<div class=\"zone z-grid\" data-zone=\"grid\" data-page=\"\(context.index + 1)\" style=\"--fit:1; grid-template-columns: repeat(\(columns), minmax(0, 1fr))\">\(inner)</div>"
        return zone("head", Array(opening), context) + grid + zone("foot", foot, context)
    }

    /// The style's columns, held to what the page's shape takes.
    static func columns(_ context: EngineContext) -> Int {
        let wanted = context.style.layout.grid.columns
        let ratio = context.size.width / context.size.height
        let most = ratio >= 1.6 ? 4 : ratio >= 1.05 ? 3 : 2
        return min(max(wanted, 2), most)
    }

    /// Each cell's span: a long text, a table or a rule takes the row; a block that would not fit what is left of its
    /// row starts the next, and the block before it widens to the row's end. (After PlateAgent's PlateSheetKit.spans.)
    static func spans(_ blocks: [PieceBlock], columns: Int) -> [Int] {
        var spans = blocks.map { block -> Int in
            if [.table, .divider].contains(block.kind) || (block.kind == .body && block.words.count > 320) { return columns }
            if block.kind == .image && columns >= 3 { return 2 }
            return 1
        }
        var used = 0
        for index in spans.indices {
            if used + spans[index] > columns, index > 0 {
                spans[index - 1] += columns - used
                used = 0
            }
            used = (used + spans[index]) % columns
        }
        if used > 0, !spans.isEmpty { spans[spans.count - 1] += columns - used }
        return spans
    }

    static let css = """
    .e-grid .z-head { flex: none; padding-bottom: calc(var(--gap) * 0.4); }
    .e-grid .z-grid { flex: 1 1 auto; display: grid; column-gap: var(--gutter); row-gap: calc(var(--gutter) * var(--fit)); align-content: start; }
    .e-grid .cell { min-width: 0; min-height: 0; display: flex; flex-direction: column; }
    .e-grid .cell > .b-stat, .e-grid .cell > .b-quote, .e-grid .cell > .b-list, .e-grid .cell > .b-steps, .e-grid .cell > .b-details {
        border-top: var(--stroke) solid var(--rule); padding-top: calc(var(--s-body) * 0.7 * var(--fit)); }
    .e-grid .cell > .b-image { min-height: calc(var(--s-body) * 9); }
    .e-grid .z-foot { flex: none; }
    """
}
