import Foundation

/// What an engine sets a page with: the page and where it falls in the piece, the format and the page's size, the
/// style's rule for this engine, and the style's book (its faces, mark and motifs) and the pictures the call gave.
public struct EngineContext: Sendable {
    public let page: PiecePage
    public let index: Int
    public let pages: Int
    public let format: PieceFormat
    public let size: PieceSize
    public let rule: StyleLayout.Rule?
    public let book: StyleBook
    /// A picture's `src` → its data URL, read by the loop from the call's folder.
    public let images: [String: String]

    public init(page: PiecePage, index: Int, pages: Int, format: PieceFormat, size: PieceSize, rule: StyleLayout.Rule?,
                book: StyleBook, images: [String: String] = [:]) {
        self.page = page; self.index = index; self.pages = pages; self.format = format; self.size = size; self.rule = rule
        self.book = book; self.images = images
    }

    public var style: AtelierStyle { book.style }

    /// The page's blocks with their places, in reading order.
    var numbered: [(Int, PieceBlock)] { Array(page.blocks.enumerated()) }

    /// Where a picture goes, by the rule, else by the page's shape.
    var imageSide: String {
        if let side = rule?.image, ["left", "right", "top", "bottom", "background"].contains(side) { return side }
        return format.isLandscape || size.width > size.height ? "left" : "top"
    }

    /// Where the headline sits in a hero: top, middle or bottom.
    var headlinePosition: String {
        if let position = rule?.headline, ["top", "middle", "bottom"].contains(position) { return position }
        return "bottom"
    }
}
