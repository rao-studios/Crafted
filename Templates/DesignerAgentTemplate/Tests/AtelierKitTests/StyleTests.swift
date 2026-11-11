import AtelierKit
import Foundation
import XCTest

/// The style as the kit reads it: the package's own and the fixtures read, roles resolve in both themes, the CSS carries
/// every role and face, a motif keeps only what draws a shape, and the colophon keeps the designer's rule.
final class StyleTests: XCTestCase {
    func testTheBundledStyleAndTheFixturesRead() throws {
        for name in Samples.styles {
            let book = try Samples.book(name)
            XCTAssertEqual(book.style.format, AtelierStyle.format, name)
            XCTAssertFalse(book.style.credit.designer.isEmpty, name)
            XCTAssertTrue(book.style.colophon.hasPrefix("Design by "), name)
            XCTAssertEqual(book.missing, [], "\(name) names only assets it has")
            for role in StyleColour.Role.allCases {
                XCTAssertNotNil(PieceColour.parse(book.style.colour.hex(role, .light)), "\(name) \(role) light")
                XCTAssertNotNil(PieceColour.parse(book.style.colour.hex(role, .dark)), "\(name) \(role) dark")
            }
        }
        let ink = try Samples.book("ink-press")
        XCTAssertEqual(ink.faces.count, 1, "the bundled italic face")
        XCTAssertEqual(ink.faces.first?.style, "italic")
        XCTAssertEqual(ink.faces.first?.weight, "400 900", "a variable face covers its axis")
    }

    func testRolesReadThePaletteInEachTheme() throws {
        let neon = try Samples.book("neon-dusk").style
        XCTAssertEqual(neon.colour.hex(.background, .dark), "#0E0B1F")
        XCTAssertEqual(neon.colour.hex(.ink, .dark), "#F4F1FF")
        XCTAssertEqual(neon.colour.naturalTheme, .dark, "most of its pieces are dark")
        let ink = try Samples.book("ink-press").style
        XCTAssertEqual(ink.colour.naturalTheme, .light)
        XCTAssertEqual(ink.colour.hex(.accent, .light), "#B3261E")
        // A style with no dark ids swaps background and ink.
        var light = ink.colour
        light.roles = ["background": .init(light: "A"), "ink": .init(light: "B")]
        XCTAssertEqual(light.hex(.background, .dark), "#101010")
        XCTAssertEqual(light.hex(.ink, .dark), "#FBF7EE")
    }

    func testTheCSSCarriesEveryRoleAndTheBundledFace() throws {
        let book = try Samples.book("ink-press")
        let css = StyleCSS.css(book, format: .poster, size: PieceFormat.poster.size, theme: .light)
        for (variable, hex) in [("--bg", "#FBF7EE"), ("--ink", "#101010"), ("--accent", "#B3261E")] {
            XCTAssertTrue(css.contains("\(variable): \(hex)"), variable)
        }
        XCTAssertTrue(css.contains("@font-face { font-family: \"Playfair Display\"; font-style: italic; font-weight: 400 900"))
        XCTAssertTrue(css.contains("--f-display: \"Playfair Display\", \"Georgia\", serif"))
        XCTAssertTrue(css.contains("--tt-label: uppercase"))
    }

    func testAMotifKeepsOnlyWhatDrawsAShape() {
        XCTAssertEqual(MotifCSS.sanitize("border-top: 3px double var(--ink); background: url(http://evil.example/x.png)"), "border-top: 3px double var(--ink)")
        XCTAssertEqual(MotifCSS.sanitize("color: red; position: fixed; @import x"), "")
        XCTAssertEqual(MotifCSS.sanitize("background: radial-gradient(circle, var(--accent), transparent 40%)"), "background: radial-gradient(circle, var(--accent), transparent 40%)")
    }

    func testTheColophonKeepsTheDesignersRule() {
        XCTAssertTrue(StyleCredit(designer: "A", colophon: .required).shows(asked: false))
        XCTAssertFalse(StyleCredit(designer: "A", colophon: .defaultOn).shows(asked: false))
        XCTAssertTrue(StyleCredit(designer: "A", colophon: .defaultOn).shows(asked: nil))
        XCTAssertFalse(StyleCredit(designer: "A", colophon: .off).shows(asked: nil))
        XCTAssertTrue(StyleCredit(designer: "A", colophon: .off).shows(asked: true))
    }
}
