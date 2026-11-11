import AtelierKit
import CoreGraphics
import Foundation
import XCTest

/// A piece as a model writes it, read loosely; held to its limits; carried in a PNG and a PDF; and set out by the engine
/// the style chooses.
final class PieceSpecTests: XCTestCase {
    func testALooseDraftReadsAsAPiece() throws {
        let json = #"""
            {"format": "One-Pager", "blocks": [{"kind": "Title", "title": "Hello"}, {"kind": "bullets", "items": "one\ntwo"},
             {"kind": "button", "text": "Go"}, {"kind": "mystery", "text": "kept as body"}, {"kind": "stat", "figure": 12}]}
            """#
        let piece = try Piece.read(Data(json.utf8))
        XCTAssertEqual(piece.format, .onepager)
        XCTAssertEqual(piece.pages.count, 1, "top-level blocks are one page")
        XCTAssertEqual(piece.pages[0].blocks.map(\.kind), [.headline, .list, .cta, .body, .stat])
        XCTAssertEqual(piece.pages[0].blocks[0].text, "Hello", "a headline written as title is its text")
        XCTAssertEqual(piece.pages[0].blocks[1].items, ["one", "two"])
        XCTAssertEqual(piece.pages[0].blocks[2].label, "Go")
        XCTAssertEqual(piece.pages[0].blocks[4].figure, "12")
        XCTAssertEqual(piece.title, "Hello")
    }

    func testAPiecePastItsLimitsIsToldAndDrawnClamped() {
        var piece = Samples.piece(.businesscard)
        piece.pages[0].blocks[1].text = String(repeating: "Long name ", count: 12)
        piece.pages[0].blocks += Array(repeating: PieceBlock(kind: .body, text: "more"), count: 4)
        let found = piece.check(format: .businesscard)
        XCTAssertTrue(found.contains { $0.sentence.contains("block 2 (headline) is 120 characters") }, "\(found.map(\.sentence))")
        XCTAssertTrue(found.contains { $0.sentence.contains("page 1 has 8 blocks") })
        let clamped = piece.clamped(format: .businesscard)
        XCTAssertEqual(clamped.pages[0].blocks.count, PieceFormat.businesscard.blockLimit)
        XCTAssertEqual(clamped.pages[0].blocks[1].text?.count, PieceLimits.text(.headline))
    }

    func testThePNGAndThePDFCarryTheSpec() throws {
        let piece = Samples.piece(.flyer)
        let png = try onePixelPNG()
        let carried = PiecePNG.embedding([(PiecePNG.keyword, piece.json), ("Author", "Ünïcode Designer")], in: png)
        XCTAssertEqual(PiecePNG.embedded(in: carried), piece.json)
        XCTAssertEqual(PiecePNG.embedded("Author", in: carried), "Ünïcode Designer")
        let pdf = try PiecePDF.merge([try onePagePDF(), try onePagePDF()],
                                     info: .init(title: "t", author: "a", subject: "s", creator: "c", spec: piece.json))
        XCTAssertEqual(PiecePDF.pageCount(pdf), 2)
        XCTAssertEqual(try Piece.read(Data(XCTUnwrap(PiecePDF.embedded(in: pdf)).utf8)), piece)
    }

    func testTheStyleChoosesTheEngineAndTheContentTipsIt() throws {
        // The template's own style, as a fixture: the bundled one is a designer's once the package is made.
        let bundled = try Samples.book("paper-and-ink").style
        XCTAssertEqual(ArchetypeChooser.choose(Samples.piece(.poster).pages[0], index: 0, format: .poster, style: bundled).0, .hero)
        XCTAssertEqual(ArchetypeChooser.choose(Samples.piece(.businesscard).pages[0], index: 0, format: .businesscard, style: bundled).0, .split)
        let brochure = Samples.piece(.brochure)
        XCTAssertEqual(ArchetypeChooser.choose(brochure.pages[0], index: 0, format: .brochure, style: bundled).0, .hero, "a cover")
        XCTAssertEqual(ArchetypeChooser.choose(brochure.pages[1], index: 1, format: .brochure, style: bundled).0, .grid, "many short things")
        let neon = try Samples.book("neon-dusk").style
        XCTAssertEqual(ArchetypeChooser.choose(Samples.piece(.businesscard).pages[0], index: 0, format: .businesscard, style: neon).0, .split)
        let ink = try Samples.book("ink-press").style
        XCTAssertEqual(ArchetypeChooser.choose(Samples.piece(.banner).pages[0], index: 0, format: .banner, style: ink).0, .hero)
        // A style that names nothing for a format falls back to the format's own.
        var bare = ink
        bare.layout.archetypes = []
        XCTAssertEqual(ArchetypeChooser.choose(Samples.piece(.flyer).pages[0], index: 0, format: .flyer, style: bare).0, .split)
    }

    private func onePixelPNG() throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func onePagePDF() throws -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 100, height: 50)
        let context = try XCTUnwrap(CGContext(consumer: XCTUnwrap(CGDataConsumer(data: data)), mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.fill(CGRect(x: 10, y: 10, width: 20, height: 20))
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
