import AtelierKit
import Foundation
import GraniteAgents
import XCTest
@testable import AtelierAgent

/// A call from the ask to the file, the host's model scripted: drafted, drawn, measured, cut, written; and a piece drawn
/// again from its own file with no model.
@MainActor
final class PieceLoopTests: XCTestCase {
    private func piece(_ blocks: [PieceBlock], format: PieceFormat = .poster) throws -> Data {
        try JSONEncoder().encode(Piece(title: "Open studios", format: format, pages: [PiecePage(blocks: blocks)]))
    }

    func testADraftThatOverflowsIsCutByTheModel() async throws {
        let folder = try Folder.make()
        let clean: [PieceBlock] = [.init(kind: .kicker, text: "14 and 15 June"), .init(kind: .headline, text: "Open studios"),
                                   .init(kind: .subhead, text: "Twelve artists, one weekend"), .init(kind: .cta, label: "Plan your visit")]
        let paragraph = String(repeating: "Every studio keeps its own hours and its own rules for the weekend. ", count: 13)
        let long = clean + Array(repeating: PieceBlock(kind: .body, text: paragraph), count: 3)
        let model = FakeHostModel([try piece(long, format: .socialcard), try piece(clean, format: .socialcard)])
        let host = AgentHost(directory: folder.path, ask: "a social card for our open studios weekend", model: model)
        let input = #"{"format": "socialcard", "brief": "open studios weekend", "content": "14 and 15 June", "output": "out/card.png", "directory": "\#(folder.path)"}"#
        let answer = try await AnyAgentPackage(AtelierAgent.self).perform(Data(input.utf8), host: host)
        let result = try JSONDecoder().decode(PieceResult.self, from: answer)
        XCTAssertEqual(result.rounds, 2, "the first draft ran past its page even set small; the second measured clean")
        XCTAssertEqual(result.findings, [])
        XCTAssertEqual(result.width, 2160)
        XCTAssertEqual(result.height, 2160)
        XCTAssertEqual(result.path, folder.appendingPathComponent("out/card.png").path)
        XCTAssertTrue(result.colophon)
        XCTAssertTrue(result.notes.first?.contains(DesignerCredit.designer) == true, "every answer credits the designer")
        XCTAssertEqual(result.made.map(\.kind), ["piece"])
        let asked = model.asked
        guard asked.count == 2 else { return XCTFail("asked \(asked.count) times") }
        XCTAssertTrue(asked[0].user.contains("a social card for our open studios weekend"), "the draft hears the person's ask")
        XCTAssertTrue(asked[0].user.contains("14 and 15 June"), "and their own words")
        XCTAssertTrue(asked[0].system.contains("Sourdough"), "with the example of another subject")
        XCTAssertTrue(asked[1].user.contains("past"), "the revision hears what the page measured: \(asked[1].user.suffix(300))")
        let png = try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(result.path)))
        XCTAssertEqual(try Piece.read(Data(XCTUnwrap(PiecePNG.embedded(in: png)).utf8)).pages[0].blocks.count, 4, "the PNG carries what it drew")
        XCTAssertEqual(PiecePNG.embedded("Author", in: png), try AtelierResources.book().style.credit.designer, "and who designed the style")
    }

    func testASpecDrawsWithNoModelAndABrochureIsAPagedPDF() async throws {
        let folder = try Folder.make()
        let brochure = Piece(title: "Weekend guide", format: .brochure, pages: [
            PiecePage(blocks: [.init(kind: .headline, text: "Open studios"), .init(kind: .subhead, text: "A weekend guide")]),
            PiecePage(blocks: [.init(kind: .headline, text: "How it runs"), .init(kind: .steps, items: ["pick up a map", "follow the doors"])]),
        ])
        let spec = String(decoding: try JSONEncoder().encode(brochure.json), as: UTF8.self)
        let input = #"{"spec": \#(spec), "format": "brochure", "directory": "\#(folder.path)"}"#
        let answer = try await AnyAgentPackage(AtelierAgent.self).perform(Data(input.utf8))
        let result = try JSONDecoder().decode(PieceResult.self, from: answer)
        XCTAssertEqual(result.pages, 2)
        XCTAssertEqual(result.rounds, 1, "nothing for a model to fix")
        let path = try XCTUnwrap(result.path)
        XCTAssertTrue(path.hasSuffix("pieces/weekend-guide-brochure.pdf"), path)
        let pdf = try Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertEqual(PiecePDF.pageCount(pdf), 2)
        // Drawn again from its own PDF, as PNGs a page.
        let again = try JSONDecoder().decode(PieceResult.self, from: try await AnyAgentPackage(AtelierAgent.self).perform(
            Data(#"{"spec": "\#(path)", "output": "proof/brochure.png", "directory": "\#(folder.path)"}"#.utf8)))
        XCTAssertEqual(again.paths.map { URL(fileURLWithPath: $0).lastPathComponent }, ["brochure.png", "brochure-p2.png"])
        XCTAssertEqual(again.title, "Weekend guide")
    }
}
