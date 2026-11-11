import Foundation

/// One layout engine: the zones it sets a page's blocks in, and the CSS of those zones. Zones carry `data-zone`, so
/// the page's fit script shrinks each zone's type (`--fit`) until what it holds fits, down to a floor; what still does
/// not fit is a finding the model hears.
protocol LayoutEngine {
    /// The page's inner HTML: its zones and their blocks.
    static func body(_ context: EngineContext) -> String
    /// The engine's CSS, under `.e-<name>`.
    static var css: String { get }
}

extension LayoutEngine {
    /// A zone: a flex column of blocks, its own `--fit`.
    static func zone(_ name: String, _ blocks: [(Int, PieceBlock)], _ context: EngineContext, extra: String = "") -> String {
        guard !blocks.isEmpty else { return "" }
        let inner = blocks.map { BlockHTML.html($0.1, id: "\(context.index + 1):\($0.0 + 1)", context: context) }.joined()
        return "<div class=\"zone z-\(name)\(extra)\" data-zone=\"\(name)\" data-page=\"\(context.index + 1)\" style=\"--fit:1\">\(inner)</div>"
    }
}
