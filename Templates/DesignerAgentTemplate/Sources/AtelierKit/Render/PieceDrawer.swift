//  WHAT: A piece drawn in a style: each page's engine chosen, its page composed, fitted, measured and exported, and
//        what the piece says that no page holds (its checks) with what the pages measured (overflow, edges), as
//        findings.
//  IN:   The loop (each round), the kit's tests (each style, each format).
//  OUT:  A DrawnPiece: the pages as PNG (and PDF pages when asked), the engines, the findings.
//  PIN:  DRAWN CLAMPED, TOLD IN FULL. The page draws the piece cut to every limit, so a model past one still gets its
//        piece; the findings name what was past the limit, so the words get fixed.

import Foundation

public struct DrawOptions: Sendable {
    public var theme: PieceTheme?
    public var size: PieceSize?
    public var colophon: Bool
    /// A picture's `src` → its data URL.
    public var images: [String: String]
    public var pdf: Bool
    /// The pages the call asked for, to hold the piece to.
    public var pages: Int?

    public init(theme: PieceTheme? = nil, size: PieceSize? = nil, colophon: Bool = true, images: [String: String] = [:], pdf: Bool = false, pages: Int? = nil) {
        self.theme = theme; self.size = size; self.colophon = colophon; self.images = images; self.pdf = pdf; self.pages = pages
    }
}

public struct DrawnPiece: Sendable {
    /// The piece as drawn: clamped to its format's limits.
    public let piece: Piece
    public let format: PieceFormat
    public let size: PieceSize
    public let theme: PieceTheme
    public let pages: [RenderedPage]
    public let archetypes: [Archetype]
    public let findings: [PieceFinding]
}

@MainActor
public enum PieceDrawer {
    public static func draw(_ piece: Piece, format: PieceFormat, book: StyleBook, renderer: PieceRenderer,
                            options: DrawOptions = DrawOptions()) async throws -> DrawnPiece {
        let size = (options.size ?? piece.size.flatMap(PieceSize.init(loose:)) ?? format.size).clamped
        let theme = options.theme ?? piece.theme ?? book.style.colour.naturalTheme
        let drawn = piece.clamped(format: format)
        var pages: [RenderedPage] = []
        var archetypes: [Archetype] = []
        for (index, page) in drawn.pages.enumerated() {
            try Task.checkCancellation()
            let (archetype, rule) = ArchetypeChooser.choose(page, index: index, format: format, style: book.style)
            let context = EngineContext(page: page, index: index, pages: drawn.pages.count, format: format, size: size, rule: rule,
                                        book: book, images: options.images)
            let html = PieceKit.page(context, archetype: archetype, theme: theme, colophon: options.colophon)
            keep(html, page: index, slug: drawn.slug)
            pages.append(try await renderer.draw(html, size: size, pdf: options.pdf, grow: StyleCSS.growCeiling(book.style)))
            archetypes.append(archetype)
        }
        let findings = piece.check(format: format, pages: options.pages) + pages.flatMap { PieceMeasure.findings($0.raw, piece: drawn) }
        return DrawnPiece(piece: drawn, format: format, size: size, theme: theme, pages: pages, archetypes: archetypes, findings: findings)
    }

    /// `PIECE_HTML=<folder>` keeps each page drawn, to open in a browser: never beside the output, where a host that
    /// indexes HTML as code would read it.
    static func keep(_ html: String, page: Int, slug: String) {
        guard let dir = ProcessInfo.processInfo.environment["PIECE_HTML"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try? html.write(to: url.appendingPathComponent("\(slug)-page-\(page + 1).html"), atomically: true, encoding: .utf8)
    }
}
