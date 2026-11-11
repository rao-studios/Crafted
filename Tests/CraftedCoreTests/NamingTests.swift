//  WHAT: Every name an agent carries comes from its display name; the word keeps to the store's pattern and stays
//        clear of words Craft already runs.

@testable import CraftedCore
import XCTest

final class NamingTests: XCTestCase {
    func testIdentityTable() {
        let cases: [(String, String, String, String)] = [
            // display given, display kept, base, word
            ("Invoice Totals", "Invoice Totals", "InvoiceTotals", "invoicetotals"),
            ("3D Größe & Co", "3D Größe & Co", "A3DGrosseCo", "a3dgrosseco"),
            ("Invoice Agent", "Invoice Agent", "Invoice", "invoice"),
            ("", "Crafted Agent", "Crafted", "crafted"),
            ("Marble", "Marble", "Marble", "marbleagent"),
        ]
        for (given, display, base, word) in cases {
            let identity = AgentIdentity.derive(display: given)
            XCTAssertEqual(identity.display, display, given)
            XCTAssertEqual(identity.base, base, given)
            XCTAssertEqual(identity.word, word, given)
            XCTAssertNil(AgentNameRules.wordProblem(identity.word), given)
        }
        let invoice = AgentIdentity.derive(display: "Invoice Totals")
        XCTAssertEqual(invoice.package, "InvoiceTotalsAgent")
        XCTAssertEqual(invoice.agentTarget, "InvoiceTotalsAgent")
        XCTAssertEqual(invoice.typeName, "InvoiceTotalsAgent")
        XCTAssertEqual(invoice.coreTarget, "InvoiceTotalsCore")
        XCTAssertEqual(invoice.kitTarget, "InvoiceTotalsKit")
        XCTAssertEqual(invoice.recordName, "invoiceTotalsRecord")
    }

    func testAWordGivenIsKeptOnlyWhenValid() {
        XCTAssertEqual(AgentIdentity.derive(display: "Invoice Totals", word: "totals").word, "totals")
        XCTAssertEqual(AgentIdentity.derive(display: "Invoice Totals", word: " Totals ").word, "totals")
        XCTAssertEqual(AgentIdentity.derive(display: "Invoice Totals", word: "has-hyphen").word, "invoicetotals")
        XCTAssertEqual(AgentIdentity.derive(display: "Invoice Totals", word: "plate").word, "invoicetotals")
        XCTAssertEqual(AgentIdentity.derive(display: String(repeating: "Long ", count: 30)).display.count, 64)
    }

    func testWordRules() {
        XCTAssertNil(AgentNameRules.wordProblem("ab"))
        XCTAssertNil(AgentNameRules.wordProblem("a1b2"))
        XCTAssertNil(AgentNameRules.wordProblem(String(repeating: "a", count: 32)))
        for bad in ["", "a", String(repeating: "a", count: 33), "1abc", "has-hyphen", "Upper", "with space", "émile", "marble", "coder"] {
            XCTAssertNotNil(AgentNameRules.wordProblem(bad), bad)
        }
        XCTAssertTrue(AgentNameRules.wordProblem("marble")!.contains("already"))
    }
}
