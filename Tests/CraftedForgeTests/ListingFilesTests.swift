//  WHAT: The listing's files: every licence's text is found, stamped with year and holder, and recognised by the
//        store's check; the painted icon is a store icon; a person's odd-sized picture is made one; LICENSE is the
//        only licence file left.

@testable import CraftedForge
import CraftedCore
import XCTest

final class ListingFilesTests: XCTestCase {
    func testEveryLicenceIsStampedAndRecognised() throws {
        for licence in ListingLicence.allCases {
            let text = try LicenceText.text(licence, holder: "Ada Lovelace", year: 2026)
            XCTAssertEqual(LicenceRecogniser.licence(in: text), licence, licence.rawValue)
            XCTAssertTrue(text.contains("2026") && text.contains("Ada Lovelace"), licence.rawValue)
            XCTAssertFalse(text.contains("{{"), licence.rawValue)
        }
    }

    func testHolderIsTheDesignerElseTheName() {
        var listing = AgentListing(name: "Swiss Mono", word: "swissmono")
        XCTAssertEqual(LicenceText.holder(for: listing), "Swiss Mono")
        listing.credit = ListingCredit(designer: "Ada Lovelace")
        XCTAssertEqual(LicenceText.holder(for: listing), "Ada Lovelace")
    }

    func testPaintedIconIsAStoreIcon() throws {
        let identity = AgentIdentity.derive(display: "Invoice Totals")
        XCTAssertEqual(DefaultIcon.initials(identity.display), "IT")
        XCTAssertEqual(DefaultIcon.initials("Marble"), "M")
        let png = try DefaultIcon.png(for: identity)
        XCTAssertEqual(IconCheck.problems(png), [])
        XCTAssertEqual(try DefaultIcon.png(for: identity), png, "the same identity paints the same tile")
        if let preview = ProcessInfo.processInfo.environment["CRAFTED_ICON_PREVIEW"] {
            try png.write(to: URL(fileURLWithPath: preview))
        }
    }

    func testWriteNormalisesAPictureAndLeavesOneLicence() throws {
        let identity = AgentIdentity.derive(display: "Invoice Totals")
        let package = try StoreFixtures.folder(["LICENSE.md": "old", "LICENCE": "old"])
        defer { try? FileManager.default.removeItem(at: package) }
        let picture = package.appendingPathComponent("wide.png")
        try StoreFixtures.png(width: 800, height: 600).write(to: picture)
        let listing = AgentListing(name: identity.display, word: identity.word, tagline: "Totals.", license: .apache2,
                                   credit: ListingCredit(designer: "Ada Lovelace"))
        try ListingFiles.write(listing: listing, icon: picture, identity: identity, role: .designer, into: package)

        let icon = try Data(contentsOf: package.appendingPathComponent("Assets/icon.png"))
        XCTAssertEqual(IconCheck.problems(icon), [])
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: package.appendingPathComponent("Assets/listing.json"))) as? [String: Any]
        XCTAssertEqual(json?["license"] as? String, "Apache-2.0")
        XCTAssertNil(json?["word"])
        XCTAssertEqual(LicenceRecogniser.licence(ofPackage: package), .apache2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: package.appendingPathComponent("LICENSE.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: package.appendingPathComponent("LICENCE").path))
    }

    func testIconRules() throws {
        XCTAssertEqual(IconCheck.problems(try StoreFixtures.png(width: 512, height: 512)), [])
        XCTAssertEqual(IconCheck.problems(try StoreFixtures.png(width: 256, height: 256)).count, 1)
        XCTAssertEqual(IconCheck.problems(Data("not a png".utf8)), ["Assets/icon.png is not a PNG: save the icon as PNG."])
        XCTAssertEqual(IconCheck.problems(Data(count: IconCheck.maxBytes + 1)).count, 1)
    }
}
