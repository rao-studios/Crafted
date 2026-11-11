import AtelierKit
import Foundation
import GraniteAgents

/// Where a piece is written and how: a PNG at 2x (one a page when a multi-page piece is asked for as PNG) or a paged
/// PDF, each carrying the spec it was drawn from and the designer's credit, and the answer that names them.
enum PieceOutput {
    /// `output` under the folder (a `.png` or `.pdf` added when it has none); else pieces/<title>, a PDF when the
    /// piece has more than one page.
    static func target(_ output: String?, folder: URL, piece: Piece, format: PieceFormat, pages: Int) -> URL {
        let ext = pages > 1 ? "pdf" : "png"
        if let output = output?.nonEmptyText {
            let url = PieceSpecFile.resolve(output, in: folder)
            return ["png", "pdf"].contains(url.pathExtension.lowercased()) ? url : url.appendingPathExtension(ext)
        }
        return folder.appendingPathComponent("pieces").appendingPathComponent("\(piece.slug)-\(format.rawValue).\(ext)")
    }

    static func write(_ drawn: DrawnPiece, to target: URL, book: StyleBook, rounds: Int, colophon: Bool, problems: [AgentProblem]) throws -> PieceResult {
        let style = book.style
        let credit = "\(style.name) by \(style.credit.designer)"
        let licence = style.credit.styleLicence.replacingOccurrences(of: "-", with: " ")
        let rights = "Style \(credit), under \(licence)."
        var paths: [URL] = []
        var existed: [Bool] = []
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if target.pathExtension.lowercased() == "pdf" {
                existed.append(manager.fileExists(atPath: target.path))
                let info = PiecePDF.Info(title: drawn.piece.title, author: style.credit.designer, subject: rights,
                                         creator: "\(AtelierAgent.display), a Craft agent", spec: drawn.piece.json)
                try PiecePDF.merge(drawn.pages.compactMap(\.pdf), info: info).write(to: target)
                paths.append(target)
            } else {
                let texts = [(PiecePNG.keyword, drawn.piece.json), ("Author", style.credit.designer), ("Copyright", rights),
                             ("Description", style.colophon), ("Software", "\(AtelierAgent.display), a Craft agent")]
                let stem = target.deletingPathExtension().lastPathComponent
                for (index, page) in drawn.pages.enumerated() {
                    // Page one where the call asked; the others beside it, numbered.
                    let url = index == 0 ? target : target.deletingLastPathComponent().appendingPathComponent("\(stem)-p\(index + 1).png")
                    existed.append(manager.fileExists(atPath: url.path))
                    try PiecePNG.embedding(texts, in: page.png).write(to: url)
                    paths.append(url)
                }
            }
        } catch {
            throw PieceError.unwritable(target.path)
        }
        let first = drawn.pages.first
        let pdf = target.pathExtension.lowercased() == "pdf"
        let findings = drawn.findings.map(\.sentence)
        var notes = ["Drawn in \(credit); the style is under \(licence): keep the credit (\"\(style.colophon)\") when you share it."]
        if !findings.isEmpty {
            notes.append("The file is written and this call is done. The findings are what the piece's own drawing kept after \(rounds) \(rounds == 1 ? "round" : "rounds") of fixing: calling again with the same brief draws the same piece, so tell the person what is left instead of calling again.")
        }
        let name = drawn.piece.slug
        let made = paths.enumerated().map { index, url in
            AgentMade(kind: "piece", name: index == 0 ? name : "\(name) page \(index + 1)", path: url.path,
                      state: existed[index] ? .rewritten : .written)
        }
        return PieceResult(
            path: paths.first?.path, paths: paths.map(\.path), piece: drawn.format.rawValue,
            width: pdf ? Int(drawn.size.width) : first?.width ?? 0, height: pdf ? Int(drawn.size.height) : first?.height ?? 0,
            pages: drawn.pages.count, archetypes: drawn.archetypes.map(\.rawValue), theme: drawn.theme.rawValue, rounds: rounds,
            findings: findings, title: drawn.piece.title, style: style.name, designer: style.credit.designer, colophon: colophon,
            notes: notes, made: made, expected: [AgentExpected(kind: "piece", name: name)], problems: problems)
    }
}
