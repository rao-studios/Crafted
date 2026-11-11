import AtelierKit
import Foundation
import XCTest

/// The kit in WebKit under very different styles: every format drawn clean at its exact size, in the style's own faces
/// and colours, with its colophon; and one piece drawn in two styles is two different pieces.
///
/// PIN: TWO TESTS, MANY PAGES. WebKit is a light GPU touch; the styles and formats are walked inside each test, on one
/// page, rather than a test each.
@MainActor
final class StyleSwapRenderTests: XCTestCase {
    func testEveryFormatDrawsCleanInEveryStyle() async throws {
        let renderer = PieceRenderer()
        for name in Samples.styles {
            let book = try Samples.book(name)
            let style = book.style
            for format in PieceFormat.allCases {
                let drawn = try await PieceDrawer.draw(Samples.piece(format), format: format, book: book, renderer: renderer)
                let label = "\(name) \(format.rawValue)"
                XCTAssertEqual(drawn.findings.map(\.sentence), [], label)
                XCTAssertEqual(drawn.pages.count, Samples.piece(format).pages.count, label)
                let theme = drawn.theme
                XCTAssertEqual(theme, style.colour.naturalTheme, label)
                for (index, page) in drawn.pages.enumerated() {
                    // PIECE_OUT=<folder> keeps every page drawn, to look at.
                    if let out = ProcessInfo.processInfo.environment["PIECE_OUT"] {
                        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
                        try? page.png.write(to: URL(fileURLWithPath: out).appendingPathComponent("\(name)-\(format.rawValue)-\(index + 1).png"))
                    }
                    XCTAssertEqual(page.width, Int(format.size.width) * 2, "\(label): twice the page's width")
                    XCTAssertEqual(page.height, Int(format.size.height) * 2, "\(label): twice the page's height")
                    let probes = page.raw.probes
                    XCTAssertEqual(probes["page"].flatMap { PieceColour.fromComputed($0.background) }, style.colour.hex(.background, theme), "\(label) background")
                    if let headline = probes["headline"] {
                        XCTAssertEqual(headline.firstFamily, style.type.role(.display).family, "\(label) display face")
                        XCTAssertEqual(PieceColour.fromComputed(headline.colour), style.colour.hex(.ink, theme), "\(label) ink")
                    }
                    if let body = probes["body"] ?? probes["lead"] {
                        XCTAssertEqual(body.firstFamily, style.type.role(.body).family, "\(label) body face")
                    }
                    XCTAssertEqual(probes["colophon"] != nil, true, "\(label): the colophon credits the designer")
                    // A bundled display face is loaded from the style's own file, not found on the Mac.
                    let display = style.type.role(.display).family
                    if probes["headline"] != nil, book.faces.contains(where: { $0.family == display }) {
                        XCTAssertTrue(page.raw.loaded.contains(display), "\(label): the bundled face loaded, \(page.raw.loaded)")
                    }
                }
            }
        }
    }

    func testOnePieceDrawsDifferentlyInTwoStyles() async throws {
        let renderer = PieceRenderer()
        let piece = Samples.piece(.poster)
        let first = try await PieceDrawer.draw(piece, format: .poster, book: Samples.book("paper-and-ink"), renderer: renderer)
        let second = try await PieceDrawer.draw(piece, format: .poster, book: Samples.book("neon-dusk"), renderer: renderer)
        XCTAssertNotEqual(first.pages[0].png, second.pages[0].png)
        XCTAssertNotEqual(first.pages[0].raw.probes["headline"]?.family, second.pages[0].raw.probes["headline"]?.family)
        XCTAssertNotEqual(first.pages[0].raw.probes["page"]?.background, second.pages[0].raw.probes["page"]?.background)
        XCTAssertEqual(first.pages[0].width, second.pages[0].width, "the same size: the style changes the look, not the page")
        // The colophon may be left off when the style allows it, and not when it requires it.
        let off = try await PieceDrawer.draw(piece, format: .poster, book: Samples.book("bundled"), renderer: renderer,
                                             options: DrawOptions(colophon: false))
        XCTAssertNil(off.pages[0].raw.probes["colophon"])
    }
}
