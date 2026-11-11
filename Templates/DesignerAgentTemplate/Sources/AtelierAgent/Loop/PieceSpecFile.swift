import AtelierKit
import Foundation

/// A piece given back to a call: its PNG (the `piece-spec` chunk), its PDF (the XMP), a JSON file, or the JSON inline.
enum PieceSpecFile {
    static func read(_ spec: String, folder: URL) throws -> Piece {
        let trimmed = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { return try Piece.read(Data(trimmed.utf8)) }
        let url = resolve(trimmed, in: folder)
        guard let data = try? Data(contentsOf: url) else { throw PieceError.spec("no file at \(url.path)") }
        switch url.pathExtension.lowercased() {
        case "png":
            guard let json = PiecePNG.embedded(in: data) else { throw PieceError.spec("\(url.lastPathComponent) carries no piece spec") }
            return try Piece.read(Data(json.utf8))
        case "pdf":
            guard let json = PiecePDF.embedded(in: data) else { throw PieceError.spec("\(url.lastPathComponent) carries no piece spec") }
            return try Piece.read(Data(json.utf8))
        default:
            return try Piece.read(data)
        }
    }

    /// A path as a call gives it: absolute, `~`, or relative to the folder.
    static func resolve(_ path: String, in folder: URL) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        return expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded) : folder.appendingPathComponent(expanded)
    }
}
