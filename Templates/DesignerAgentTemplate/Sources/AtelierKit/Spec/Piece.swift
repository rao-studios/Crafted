//  WHAT: A piece as the host's model writes it, and as its PNG or PDF carries it: what it is called, its format, its
//        theme, and its pages of blocks. Everything else (the engine, the type, the colours, the motifs) is the kit's
//        and the style's.
//  OUT:  The loop (drafted, revised, drawn), the PNG's `piece-spec` chunk and the PDF's XMP (redrawn with no model).

import Foundation

public struct Piece: Codable, Sendable, Equatable {
    /// What a piece's embedded spec says it is.
    public static let form = "crafted-piece/1"

    public var form = Piece.form
    /// What the piece is called: its file's name and the PDF's title. Not drawn.
    public var title: String
    public var format: PieceFormat?
    public var theme: PieceTheme?
    /// A size the call asked for, as written ("1200x1600", "a4").
    public var size: String?
    public var pages: [PiecePage]

    public init(title: String, format: PieceFormat? = nil, theme: PieceTheme? = nil, size: String? = nil, pages: [PiecePage]) {
        self.title = title; self.format = format; self.theme = theme; self.size = size; self.pages = pages
    }

    enum CodingKeys: String, CodingKey { case form, title, format, theme, size, pages, blocks }

    /// A piece written with one page's `blocks` at the top, and no `pages`, is that one page.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = PieceLoose.string(c, .title)?.nonEmptyText ?? ""
        format = try? c.decodeIfPresent(PieceFormat.self, forKey: .format)
        theme = try? c.decodeIfPresent(PieceTheme.self, forKey: .theme)
        size = PieceLoose.string(c, .size)?.nonEmptyText
        pages = PieceLoose.list(c, .pages, of: PiecePage.self).filter { !$0.blocks.isEmpty }
        if pages.isEmpty {
            let blocks = PieceLoose.list(c, .blocks, of: PieceBlock.self)
            if !blocks.isEmpty { pages = [PiecePage(blocks: blocks)] }
        }
        if title.isEmpty { title = pages.first?.first(.headline)?.text ?? "piece" }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(form, forKey: .form)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(format, forKey: .format)
        try c.encodeIfPresent(theme, forKey: .theme)
        try c.encodeIfPresent(size, forKey: .size)
        try c.encode(pages, forKey: .pages)
    }

    /// The piece as compact JSON, keys sorted: what a PNG or PDF carries and what a revision is shown.
    public var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    /// A piece from JSON, or why it does not read.
    public static func read(_ data: Data) throws -> Piece {
        do {
            let piece = try JSONDecoder().decode(Piece.self, from: data)
            guard !piece.pages.isEmpty else { throw PieceError.spec("the piece has no blocks") }
            return piece
        } catch let error as PieceError {
            throw error
        } catch {
            throw PieceError.spec(PieceLoose.describe(error))
        }
    }

    /// A file name from the title: lowercase words joined by `-`.
    public var slug: String {
        let slug = String(PieceLoose.slug(title).prefix(48)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "piece" : slug
    }
}
