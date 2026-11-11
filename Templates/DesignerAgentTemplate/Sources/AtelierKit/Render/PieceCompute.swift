import Foundation

/// What every piece is drawn with: one WebKit page and the package's style, made on the first call and kept.
///
/// PIN: NOTHING AT BOOTSTRAP. An app that links the package and never asks for a piece makes no page and reads no
/// style; the first call does both, on main, where WebKit lives. (After PlateAgent's PlateCompute.)
@MainActor
public final class PieceCompute {
    private var renderer: PieceRenderer?
    private var loaded: StyleBook?

    public init() {}

    /// The package's own style.
    public func book() throws -> StyleBook {
        if let loaded { return loaded }
        let book = try AtelierResources.book()
        loaded = book
        return book
    }

    public var page: PieceRenderer {
        if let renderer { return renderer }
        let made = PieceRenderer()
        renderer = made
        return made
    }
}

extension PieceCompute {
    /// A piece drawn on this compute's page in `book`'s style.
    public func draw(_ piece: Piece, format: PieceFormat, book: StyleBook, options: DrawOptions) async throws -> DrawnPiece {
        try await PieceDrawer.draw(piece, format: format, book: book, renderer: page, options: options)
    }
}
