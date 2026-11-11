import Foundation

/// One block as the page draws it: its kind's element and class, its words escaped. Every block carries
/// `data-block="<page>:<block>"`, so what the page measures names the block the model wrote.
public enum BlockHTML {
    public static func html(_ block: PieceBlock, id: String, context: EngineContext) -> String {
        let esc = PieceHTML.escape, inline = PieceHTML.inline
        let tag = "data-block=\"\(id)\""
        let title = block.title.map { "<div class=\"bt\">\(inline($0))</div>" } ?? ""
        switch block.kind {
        case .headline:
            return "<h1 class=\"blk b-headline\" \(tag)>\(inline(block.text ?? ""))</h1>"
        case .kicker:
            return "<div class=\"blk b-kicker\" \(tag)>\(inline(block.text ?? ""))</div>"
        case .subhead:
            return "<h2 class=\"blk b-subhead\" \(tag)>\(inline(block.text ?? ""))</h2>"
        case .lead:
            return "<p class=\"blk b-lead\" \(tag)>\(inline(block.text ?? ""))</p>"
        case .body:
            let paragraphs = (block.text ?? "").components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return "<div class=\"blk b-body\" \(tag)>" + title + paragraphs.map { "<p>\(inline($0))</p>" }.joined() + "</div>"
        case .list:
            return "<div class=\"blk b-list\" \(tag)>" + title + "<ul>" + block.items.map { "<li>\(inline($0))</li>" }.joined() + "</ul></div>"
        case .steps:
            return "<div class=\"blk b-steps\" \(tag)>" + title + "<ol>" + block.items.enumerated().map { n, item in
                "<li><span class=\"n\">\(String(format: "%02d", n + 1))</span><span>\(inline(item))</span></li>"
            }.joined() + "</ol></div>"
        case .stat:
            let caption = [block.text ?? block.title].compactMap { $0 }.map { "<div class=\"cap\">\(inline($0))</div>" }.joined()
            return "<div class=\"blk b-stat\" \(tag)><div class=\"fig\">\(esc(block.figure ?? ""))</div>\(caption)</div>"
        case .quote:
            let words = (block.text ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\"“”‘’' \n"))
            return "<figure class=\"blk b-quote\" \(tag)><blockquote>“\(inline(words))”</blockquote>"
                + (block.by.map { "<figcaption>— \(esc($0))</figcaption>" } ?? "") + "</figure>"
        case .callout:
            return "<aside class=\"blk b-callout\" \(tag)>" + title + (block.text.map { "<p>\(inline($0))</p>" } ?? "") + "</aside>"
        case .details:
            let rows = block.items.map { item -> String in
                let parts = item.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                return parts.count == 2 && !parts[0].isEmpty && parts[0].count <= 24
                    ? "<dt>\(esc(parts[0]))</dt><dd>\(inline(parts[1]))</dd>" : "<dt></dt><dd>\(inline(item))</dd>"
            }
            return "<dl class=\"blk b-details\" \(tag)>" + rows.joined() + "</dl>"
        case .table:
            guard let head = block.rows.first else { return "" }
            let width = block.rows.map(\.count).max() ?? head.count
            func cells(_ row: [String], _ cell: String) -> String {
                (0..<width).map { "<\(cell)>\(esc($0 < row.count ? row[$0] : ""))</\(cell)>" }.joined()
            }
            return "<table class=\"blk b-table\" \(tag)><thead><tr>\(cells(head, "th"))</tr></thead><tbody>"
                + block.rows.dropFirst().map { "<tr>\(cells($0, "td"))</tr>" }.joined() + "</tbody></table>"
        case .image:
            return image(block, tag: tag, context: context)
        case .cta:
            return "<div class=\"blk b-cta\" \(tag)><span class=\"btn\">\(esc(block.label ?? block.text ?? ""))</span>"
                + (block.label != nil ? block.text.map { "<span class=\"where\">\(inline($0))</span>" } ?? "" : "") + "</div>"
        case .logo:
            if let mark = context.book.mark {
                return "<div class=\"blk b-logo\" \(tag)><img src=\"\(mark)\" alt=\"\(esc(block.text ?? context.style.credit.designer))\"></div>"
            }
            return "<div class=\"blk b-logo\" \(tag)>\(esc(block.text ?? context.style.name))</div>"
        case .divider:
            return "<hr class=\"blk b-divider\" \(tag)>"
        case .footer:
            return "<div class=\"blk b-footer\" \(tag)>\(inline(block.text ?? ""))</div>"
        }
    }

    /// A picture the call gave, cropped to its box; or a stand-in in the style's placeholder treatment, so the piece
    /// shows where a picture goes and never ships one of the designer's.
    static func image(_ block: PieceBlock, tag: String, context: EngineContext) -> String {
        let esc = PieceHTML.escape
        let caption = block.alt.map { "<figcaption>\(esc($0))</figcaption>" } ?? ""
        if let src = block.src, let data = context.images[src] {
            return "<figure class=\"blk b-image\" \(tag)><div class=\"ph\"><img src=\"\(data)\" alt=\"\(esc(block.alt ?? ""))\"></div>\(caption)</figure>"
        }
        let treatment = ["solid", "gradient", "duotone", "pattern"].contains(context.style.imagery.placeholder) ? context.style.imagery.placeholder : "solid"
        return "<figure class=\"blk b-image\" \(tag)><div class=\"ph ph-\(treatment)\"></div>\(caption)</figure>"
    }
}
