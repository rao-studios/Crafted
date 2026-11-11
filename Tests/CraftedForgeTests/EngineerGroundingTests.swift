import CraftedCore
import Foundation
import XCTest
@testable import CraftedForge

/// A card is held to its file's lines: ranges exist, operations are named on their lines, a rule's numbers and strings
/// are in its range. What is not is struck, and a card that is mostly ungrounded goes back to the model.
final class EngineerGroundingTests: XCTestCase {
    let lines = SourceText.lines("""
        def convert_length(value, from_unit, to_unit):
            if from_unit not in LENGTH:
                raise ValueError("unknown length unit")
            metres = value * LENGTH[from_unit]
            return metres / LENGTH[to_unit] * 1.0
        """)

    func card(operations: [FileCard.Operation] = [], rules: [FileCard.Rule] = [], entities: [FileCard.Entity] = []) -> FileCard {
        FileCard(path: "length.py", sha256: "", language: "python", lines: lines.count, role: "logic", summary: "s",
                 entities: entities, operations: operations, rules: rules)
    }

    func testAGroundedCardKeepsEverything() {
        let grounded = card(operations: [.init(name: "convert_length", signature: nil, lines: LineRange(1, 5), does: nil, purity: nil)],
                            rules: [.init(statement: "A length goes through metres, times 1.0.", formula: "metres = value * LENGTH[from_unit]", lines: LineRange(4, 5)),
                                    .init(statement: "An \"unknown length unit\" is refused.", formula: nil, lines: LineRange(3, 3))])
        XCTAssertEqual(CardGrounding.problems(grounded, lines: lines), [])
        XCTAssertEqual(CardGrounding.strike(grounded, lines: lines), grounded)
    }

    func testARangeOutsideTheFileIsStruck() {
        let struck = CardGrounding.strike(card(entities: [.init(name: "LENGTH", kind: nil, lines: LineRange(4, 40))]), lines: lines)
        XCTAssertTrue(struck.entities.isEmpty)
        XCTAssertTrue(struck.struck.first?.contains("not in the file") == true, "\(struck.struck)")
    }

    func testAnOperationNotNamedOnItsLinesIsStruck() {
        let struck = CardGrounding.strike(card(operations: [.init(name: "convert_mass", signature: "convert_mass(v)", lines: LineRange(1, 5), does: nil, purity: nil)]), lines: lines)
        XCTAssertTrue(struck.operations.isEmpty)
        XCTAssertTrue(struck.struck.first?.contains("not named") == true)
    }

    func testANumberOrStringARuleDoesNotFindInItsRangeIsStruck() {
        let number = card(rules: [.init(statement: "A length is scaled by 1609.344.", formula: nil, lines: LineRange(4, 5))])
        XCTAssertEqual(CardGrounding.strike(number, lines: lines).rules, [])
        let quoted = card(rules: [.init(statement: "It refuses \"furlong\".", formula: nil, lines: LineRange(1, 5))])
        XCTAssertEqual(CardGrounding.strike(quoted, lines: lines).rules, [])
        let elsewhere = card(rules: [.init(statement: "It times 1.0.", formula: nil, lines: LineRange(1, 2))])
        XCTAssertEqual(CardGrounding.strike(elsewhere, lines: lines).rules, [], "1.0 is on line 5, not in 1-2")
    }

    func testAMostlyUngroundedCardIsSentBackAndAMostlyGroundedOneIsNot() {
        let bad = card(operations: [.init(name: "nope", signature: nil, lines: LineRange(1, 2), does: nil, purity: nil)],
                       rules: [.init(statement: "It uses 42.", formula: nil, lines: LineRange(1, 5))])
        XCTAssertTrue(CardGrounding.isMostlyUngrounded(bad, lines: lines))
        let good = card(operations: [.init(name: "convert_length", signature: nil, lines: LineRange(1, 5), does: nil, purity: nil),
                                     .init(name: "nope", signature: nil, lines: LineRange(1, 2), does: nil, purity: nil)],
                        rules: [.init(statement: "It times 1.0.", formula: nil, lines: LineRange(5, 5))])
        XCTAssertFalse(CardGrounding.isMostlyUngrounded(good, lines: lines))
    }

    func testLineRangesReadHoweverAModelWritesThem() throws {
        for (json, range) in [("\"12-18\"", LineRange(12, 18)), ("\"L3-L4\"", LineRange(3, 4)), ("7", LineRange(7, 7)), ("[2, 9]", LineRange(2, 9))] {
            XCTAssertEqual(try JSONDecoder().decode(LineRange.self, from: Data(json.utf8)), range)
        }
    }

    func testTheInventoryWithholdsSecretNamesAndRedactsSecretsBeforeAnyPrompt() throws {
        try EngineerPaths.requireFixtures()
        let read = InventoryReader.read(EngineerPaths.project("py-unit-converter"))
        let inventory = read.inventory
        XCTAssertEqual(inventory.file(".env")?.verdict, .withheld)
        XCTAssertNil(inventory.text(".env"), "a withheld file is never opened")
        let config = inventory.text("converter/config.py") ?? ""
        XCTAssertFalse(config.contains("exr_4f7Qz9TmW2xK8pLr3VbN6cYd"), "the planted key never reaches a prompt")
        XCTAssertTrue(config.contains(SecretScan.placeholder))
        XCTAssertEqual(inventory.file("tests/test_length.py")?.verdict, .test)
        XCTAssertEqual(inventory.file("converter/cli.py")?.verdict, .read)
        XCTAssertEqual(inventory.licence, "MIT")
        XCTAssertTrue(read.findings.contains { $0.kind == .withheld && $0.path == ".env" })
        XCTAssertTrue(read.findings.contains { $0.kind == .secret && $0.path == "converter/config.py" })
        let order = ImportGraph.of(inventory).order
        XCTAssertLessThan(order.firstIndex(of: "converter/units.py") ?? 99, order.firstIndex(of: "converter/length.py") ?? -1, "leaves first")
        XCTAssertEqual(order.last, "converter/cli.py", "the entry file last")
    }
}
