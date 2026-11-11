import AtelierKit
import Foundation

/// The person's own pictures a piece names (an image block's `src`), read from the call's folder as data URLs, so the
/// page fetches nothing. A picture that is missing, too large or not a picture is drawn as the style's stand-in.
enum PieceImages {
    static func read(_ piece: Piece, folder: URL) -> [String: String] {
        var images: [String: String] = [:]
        for page in piece.pages {
            for block in page.blocks where block.kind == .image {
                guard let src = block.src, images[src] == nil else { continue }
                if let data = StyleBook.dataURL(PieceSpecFile.resolve(src, in: folder), limit: 8_000_000) { images[src] = data }
            }
        }
        return images
    }
}
