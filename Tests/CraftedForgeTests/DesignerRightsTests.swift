import CraftedCore
@testable import CraftedForge
import Foundation
import XCTest

/// What may ship, by default: an open face ships, any other is stood in for; a file named as the designer's mark is
/// offered and taken, a "logo" is offered and not taken, a client's logo seen on a piece is never offered; the credit
/// is the name in Settings, else the folder's.
final class DesignerRightsTests: XCTestCase {
    private func face(_ family: String, open: String?) -> FontFact {
        FontFact(path: "Fonts/\(family).ttf", family: family, style: "Regular", postScript: family, weight: 400, italic: false, class: "serif",
                 licenceText: open.map { "Licensed under the \($0)" }, licenceURL: nil, licenceFile: nil, openLicence: open)
    }

    func testAnOpenFaceShipsAndAnyOtherIsStoodInFor() {
        let decisions = DesignRights.fontDecisions([face("Playfair Display", open: "OFL-1.1"), face("Velour Grotesk", open: nil)])
        let open = decisions.first { $0.family == "Playfair Display" }!.decision
        XCTAssertEqual(open.defaultOption, "open")
        XCTAssertEqual(open.kind, .fontRights)
        XCTAssertEqual(open.options.map(\.id), ["open", "attest", "substitute"])
        let closed = decisions.first { $0.family == "Velour Grotesk" }!.decision
        XCTAssertEqual(closed.defaultOption, "substitute", "nothing says it may ship")
        XCTAssertEqual(closed.options.map(\.id), ["attest", "substitute"], "no open option for a face that is not open")
    }

    func testTheDesignersMarkIsTakenAndAClientsLogoNeverOffered() {
        let mark = DesignRights.markDecision(["mark.svg", "logo.png"], looks: [])!
        XCTAssertEqual(mark.defaultOption, "mark.svg", "a file named as the designer's mark")
        XCTAssertEqual(mark.options.map(\.id), ["mark.svg", "logo.png", "none"])
        XCTAssertEqual(DesignRights.markDecision(["logo.png"], looks: [])?.defaultOption, "none", "a logo may be a client's")
        let client = DesignerSupport.look(background: "A", ink: "B", marks: [.init(what: "client-logo", where: "bottom-right", text: "ACME CORP")])
        XCTAssertNil(DesignRights.markDecision(["acme-logo.png"], looks: [client]), "a client's logo is never offered")
        XCTAssertEqual(DesignRights.markDecision(["acme-logo.png", "monogram.svg"], looks: [client])?.options.map(\.id), ["monogram.svg", "none"])
    }

    func testTheCreditIsSettingsElseTheFolders() {
        let declared = DesignMeasures.Credit(name: "Mira Hale", url: "https://swissmono.example", source: "about.txt")
        XCTAssertTrue(DesignRights.creditDecision(options: ForgeOptions(credit: "Ada Moreno"), declared: declared).question.contains("Ada Moreno"))
        XCTAssertTrue(DesignRights.creditDecision(options: ForgeOptions(), declared: declared).question.contains("Mira Hale"))
        XCTAssertEqual(DesignMeasures.credit(in: ["about.txt": "Swiss Mono\n\nDesigned by Mira Hale\nhttps://swissmono.example\n"])?.name, "Mira Hale")
        XCTAssertEqual(DesignMeasures.credit(in: ["about.txt": "Design by Teo Brandt\n"])?.name, "Teo Brandt")
    }
}
