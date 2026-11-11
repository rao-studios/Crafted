//  WHAT: One call, from the ask to the file: read the spec or draft the piece on the host's model, then a round at a time
//        draw it (each page's engine, the type fitted, measured) and hand what was found back to the model to fix,
//        until it measures clean or the rounds are spent. The best round is written, its spec and credit inside it.
//        (The loop's shape is PlateAgent's PlateLoop+Sheet.)
//  PIN:  THE MODEL DECIDES WHAT THE PIECE SAYS; IT NEVER PLACES ANYTHING. What it hears back is what the page measured,
//        as sentences it can act on.
//  PIN:  A SPEC DRAWS WITH NO MODEL. A piece's PNG, PDF or JSON (or the JSON itself, inline) is drawn as it is, so a
//        host with no model, and Crafted's proof, still get a piece.

import AtelierKit
import Foundation
import GraniteAgents

struct PieceLoop: Sendable {
    let input: AtelierAgent.Input
    let context: AtelierAgent.Context
    let yield: @Sendable (PieceFrame) -> Void

    func run() async throws -> PieceResult {
        let host = context.host
        let folder = URL(fileURLWithPath: ((input.directory ?? host.directory ?? FileManager.default.currentDirectoryPath) as NSString).expandingTildeInPath)
        let rounds = min(max(input.rounds ?? 3, 1), 6)
        let compute = context.compute
        let book = try await compute.book()
        let style = book.style
        var piece: Piece
        var model = host.model
        if let spec = input.spec?.nonEmptyText {
            piece = try PieceSpecFile.read(spec, folder: folder)
            // A spec and a brief: what the brief asks, made on the spec before it is drawn again.
            if let brief = input.brief?.nonEmptyText, let offered = model {
                host.note("changing the piece: \(brief.prefix(80))")
                if let changed = try? await ask(offered, system: PieceDraft.reviseSystem(style), user: PieceDraft.change(piece, brief: brief)),
                   !changed.pages.isEmpty {
                    piece = changed
                }
            } else if input.brief?.nonEmptyText == nil {
                // Drawn as it is: nothing for a model to fix.
                model = nil
            }
        } else {
            guard let offered = model else { throw PieceError.noModel(AtelierAgent.word) }
            host.note("writing the \((input.format ?? .poster).title) in \(style.name)")
            piece = try await ask(offered, system: PieceDraft.system(style),
                                  user: PieceDraft.draft(ask: host.ask, input: input, style: style))
            yield(.drafted(piece))
        }
        guard !piece.pages.isEmpty else { throw PieceError.empty("no blocks") }

        let format = input.format ?? piece.format ?? .poster
        piece.format = format
        if let theme = input.theme { piece.theme = theme }
        if let size = input.size?.nonEmptyText {
            guard PieceSize(loose: size) != nil else {
                throw PieceError.call("`size` \"\(size)\" is not a size: give it as 1200x1600 in CSS pixels, or a4, a5, letter, square or 16:9")
            }
            piece.size = size
        }
        let wanted = input.pages.map { min(max($0, 1), format.maxPages) }
        let target = PieceOutput.target(input.output, folder: folder, piece: piece, format: format, pages: max(wanted ?? piece.pages.count, 1))
        let colophon = style.credit.shows(asked: input.credit)
        let images = PieceImages.read(piece, folder: folder)
        let options = DrawOptions(theme: piece.theme, size: piece.size.flatMap(PieceSize.init(loose:)), colophon: colophon, images: images,
                                  pdf: target.pathExtension.lowercased() == "pdf", pages: wanted)

        var best: DrawnPiece?
        var last = 0
        for round in 1...rounds {
            try Task.checkCancellation()
            last = round
            let drawn = try await compute.draw(piece, format: format, book: book, options: options)
            let found = drawn.findings
            yield(.measured(round: round, findings: found))
            host.note(found.isEmpty ? "round \(round): measured clean" : "round \(round): \(found.count) to fix — \(found[0].sentence)")
            if best == nil || found.count <= best!.findings.count { best = drawn }
            guard !found.isEmpty, round < rounds, let offered = model else { break }
            host.note("revising the piece")
            // A revision that changes nothing would draw the same page: the rounds end there.
            guard let revised = try? await ask(offered, system: PieceDraft.reviseSystem(style), user: PieceDraft.revise(piece, findings: found)),
                  !revised.pages.isEmpty, revised.pages != piece.pages else { break }
            piece.pages = revised.pages
            yield(.revised(round: round))
        }
        guard let best else { throw PieceError.render("no round drew") }
        var problems = book.missing.map { AgentProblem(kind: "fallback", text: "the style names \($0) and it was not found: the piece was drawn without it.") }
        if input.credit == false, colophon {
            problems.append(AgentProblem(kind: "credit", text: "\(style.credit.designer) requires the colophon, so the piece keeps it."))
        }
        return try PieceOutput.write(best, to: target, book: book, rounds: last, colophon: colophon, problems: problems)
    }

    private func ask(_ model: any AgentHostModel, system: String, user: String) async throws -> Piece {
        let data = try await model.object(schema: PieceDraft.schema, system: system, user: user, maxTokens: 3_000, seconds: 300)
        do {
            return try Piece.read(data)
        } catch {
            throw AgentHostError.answer("\(error)")
        }
    }
}
