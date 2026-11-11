//  WHAT: The listing form's rules (the store's limits as sentences by field), and a suggestion merged under the
//        person's edits: an edited key is never overwritten; fields always follow the agent.

@testable import CraftedCore
import XCTest

final class ListingTests: XCTestCase {
    func good() -> AgentListing {
        AgentListing(name: "Invoice Totals", word: "invoicetotals", tagline: "Totals a folder of invoices.", category: .data,
                     keywords: ["invoices", "c++", "csv export"], platforms: ["macOS 26"], license: .mit)
    }

    func testAGoodListingHasNoProblems() {
        XCTAssertEqual(ListingRules.problems(good(), role: .engineer), [])
    }

    func testEachRuleSaysItsField() {
        func keys(_ change: (inout AgentListing) -> Void, role: CraftedRole = .engineer) -> [ListingKey] {
            var listing = good()
            change(&listing)
            return ListingRules.problems(listing, role: role).map(\.key)
        }
        XCTAssertEqual(keys { $0.name = "  " }, [.name])
        XCTAssertEqual(keys { $0.name = String(repeating: "n", count: 65) }, [.name])
        XCTAssertEqual(keys { $0.word = "Bad-Word" }, [.word])
        XCTAssertEqual(keys { $0.tagline = "" }, [.tagline])
        XCTAssertEqual(keys { $0.tagline = String(repeating: "t", count: 141) }, [.tagline])
        XCTAssertEqual(keys { $0.keywords = (1...9).map { "k\($0)" } }, [.keywords])
        XCTAssertEqual(keys { $0.keywords = ["Bad!"] }, [.keywords])
        XCTAssertEqual(keys { $0.platforms = [] }, [.platforms])
        XCTAssertEqual(keys { $0.platforms = Array(repeating: "macOS 26", count: 9) }, [.platforms])
        XCTAssertEqual(keys({ $0.credit = nil }, role: .designer), [.credit])
        XCTAssertEqual(keys({ $0.credit = ListingCredit(designer: "Ada", url: "ftp://x") }, role: .designer), [.credit])
        XCTAssertEqual(keys({ $0.credit = ListingCredit(designer: "Ada", url: "https://ada.dev") }, role: .designer), [])
    }

    func testKeywords() {
        for good in ["a", "c++", "c#", "node.js", "dark mode", "x-y", String(repeating: "k", count: 24)] {
            XCTAssertTrue(ListingRules.isKeyword(good), good)
        }
        for bad in ["", " lead", "-lead", "Upper", "émoji", String(repeating: "k", count: 25), "under_score"] {
            XCTAssertFalse(ListingRules.isKeyword(bad), bad)
        }
        XCTAssertEqual(ListingRules.keyword(from: "  Dark Mode! "), "dark mode")
        XCTAssertEqual(ListingRules.keyword(from: "--Swift"), "swift")
        XCTAssertNil(ListingRules.keyword(from: "!!!"))
    }

    func testMergingKeepsEditedKeys() {
        var mine = good()
        mine.name = "My Totals"
        mine.tagline = "Mine."
        mine.edited = [.name, .tagline]
        let suggestion = AgentListing(name: "Suggested", word: "suggested", tagline: "Suggested.", category: .developer,
                                      keywords: ["x"], license: .apache2,
                                      fields: [ListingField(name: "folder", type: "string", required: true, note: "the invoices")])
        let merged = mine.merging(suggestion: suggestion)
        XCTAssertEqual(merged.name, "My Totals")
        XCTAssertEqual(merged.tagline, "Mine.")
        XCTAssertEqual(merged.word, "suggested")
        XCTAssertEqual(merged.category, .developer)
        XCTAssertEqual(merged.license, .apache2)
        XCTAssertEqual(merged.fields.map(\.name), ["folder"])
        XCTAssertEqual(merged.edited, [.name, .tagline])

        // A suggestion without a credit never wipes one.
        var credited = good()
        credited.credit = ListingCredit(designer: "Ada")
        XCTAssertEqual(credited.merging(suggestion: suggestion).credit?.designer, "Ada")
    }

    func testStoreJSONLeavesOutWordAndEdits() throws {
        var listing = good()
        listing.edited = [.name]
        let json = try JSONSerialization.jsonObject(with: listing.storeJSON()) as? [String: Any]
        XCTAssertEqual(Set(json?.keys.map { $0 } ?? []), ["name", "tagline", "category", "keywords", "platforms", "license", "fields"])
        XCTAssertEqual(json?["license"] as? String, "MIT")
    }
}
