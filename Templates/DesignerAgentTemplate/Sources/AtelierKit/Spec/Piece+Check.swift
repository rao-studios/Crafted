import Foundation

/// What a piece says that no page can hold, found before it is drawn: a text past its kind's limit, a list too long, a
/// page with more blocks than its format holds, more pages than the format takes, a first page with no headline. Each
/// is a sentence the model can act on. `clamped` is the piece drawn meanwhile: cut to every limit, so a model past one
/// still gets its piece.
extension Piece {
    public func check(format: PieceFormat, pages wanted: Int? = nil) -> [PieceFinding] {
        var found: [PieceFinding] = []
        if pages.count > format.maxPages {
            found.append(PieceFinding(.limit, "pages", numbers: [pages.count, format.maxPages],
                                      "the piece has \(pages.count) pages and a \(format.title) takes \(format.maxPages): fold it into \(format.maxPages)."))
        }
        if let wanted, wanted != pages.count, wanted <= format.maxPages {
            found.append(PieceFinding(.limit, "pages", numbers: [pages.count, wanted],
                                      "the piece has \(pages.count) pages and \(wanted) were asked for: write \(wanted)."))
        }
        if pages.first?.first(.headline) == nil {
            found.append(PieceFinding(.missing, "page 1", "the first page has no headline: add one block of kind headline."))
        }
        for (p, page) in pages.prefix(format.maxPages).enumerated() {
            if page.blocks.count > format.blockLimit {
                found.append(PieceFinding(.limit, "page \(p + 1)", numbers: [page.blocks.count, format.blockLimit],
                                          "page \(p + 1) has \(page.blocks.count) blocks and a \(format.title) page holds \(format.blockLimit): merge or drop \(page.blocks.count - format.blockLimit)."))
            }
            for (b, block) in page.blocks.enumerated() {
                let name = Piece.describe(page: p, block: b, block)
                if let text = block.text, text.count > PieceLimits.text(block.kind) {
                    found.append(PieceFinding(.limit, Piece.element(p, b), numbers: [text.count, PieceLimits.text(block.kind)],
                                              "\(name) is \(text.count) characters and holds \(PieceLimits.text(block.kind)): cut it."))
                }
                if block.items.count > PieceLimits.items(block.kind) {
                    found.append(PieceFinding(.limit, Piece.element(p, b), numbers: [block.items.count, PieceLimits.items(block.kind)],
                                              "\(name) has \(block.items.count) lines and holds \(PieceLimits.items(block.kind)): keep the strongest."))
                }
                if let long = block.items.first(where: { $0.count > PieceLimits.item }) {
                    found.append(PieceFinding(.limit, Piece.element(p, b), numbers: [long.count, PieceLimits.item],
                                              "a line of \(name) is \(long.count) characters and holds \(PieceLimits.item): shorten \"\(long.prefix(32))…\"."))
                }
                if let figure = block.figure, figure.count > PieceLimits.figure {
                    found.append(PieceFinding(.limit, Piece.element(p, b), numbers: [figure.count, PieceLimits.figure],
                                              "\(name)'s figure \"\(figure)\" is longer than a figure reads: \(PieceLimits.figure) characters at most, the rest in its text."))
                }
                if block.rows.count > PieceLimits.rows || block.rows.contains(where: { $0.count > PieceLimits.columns }) {
                    found.append(PieceFinding(.limit, Piece.element(p, b), numbers: [block.rows.count, PieceLimits.rows],
                                              "\(name) holds \(PieceLimits.rows) rows of \(PieceLimits.columns) cells at most."))
                }
                if block.kind == .stat, block.figure == nil {
                    found.append(PieceFinding(.missing, Piece.element(p, b), "\(name) has no figure: give it one, or make it a body."))
                }
                if block.kind == .table, block.rows.isEmpty {
                    found.append(PieceFinding(.missing, Piece.element(p, b), "\(name) has no rows: give it rows, or drop it."))
                }
                if [.list, .steps, .details].contains(block.kind), block.items.isEmpty {
                    found.append(PieceFinding(.missing, Piece.element(p, b), "\(name) has no items: give it items, or make it a body."))
                }
            }
        }
        return found
    }

    /// The piece cut to every limit, and to its format's pages and blocks.
    public func clamped(format: PieceFormat) -> Piece {
        var piece = self
        piece.pages = Array(pages.prefix(format.maxPages)).map { page in
            var page = page
            page.blocks = Array(page.blocks.prefix(format.blockLimit)).map { $0.clamped() }
            return page
        }
        return piece
    }

    /// "page 2 · block 3 (body)"; one page's pieces say only the block.
    static func describe(page: Int, block: Int, _ value: PieceBlock) -> String {
        (page > 0 ? "page \(page + 1), " : "") + "block \(block + 1) (\(value.kind.rawValue))"
    }

    static func element(_ page: Int, _ block: Int) -> String { "page:\(page + 1):block:\(block + 1)" }
}

extension PieceBlock {
    /// The block cut to its kind's limits.
    public func clamped() -> PieceBlock {
        func cut(_ text: String?, _ limit: Int) -> String? {
            guard let text, text.count > limit else { return text }
            return String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
        }
        var block = self
        block.text = cut(text, PieceLimits.text(kind))
        block.title = cut(title, PieceLimits.title)
        block.items = Array(items.prefix(PieceLimits.items(kind))).compactMap { cut($0, PieceLimits.item) }
        block.figure = cut(figure, PieceLimits.figure)
        block.by = cut(by, PieceLimits.by)
        block.label = cut(label, PieceLimits.label)
        block.rows = Array(rows.prefix(PieceLimits.rows)).map { Array($0.prefix(PieceLimits.columns)).compactMap { cut($0, PieceLimits.cell) } }
        return block
    }
}
