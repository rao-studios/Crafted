import CraftedCore
import Foundation
import XCTest
@testable import CraftedForge

/// An interpretation rests on verified use cases and the inventory's files, keeps its lens's size, and differs from
/// the others; a plan keeps the agent's limits.
final class EngineerInterpretTests: XCTestCase {
    override func setUpWithError() throws { try EngineerPaths.requireFixtures() }

    let inventory = InventoryReader.read(EngineerPaths.project("py-unit-converter")).inventory

    func command(_ name: String, usecases: [String], args: Int = 1) -> InterpretationCard.Command {
        InterpretationCard.Command(name: name, summary: "s", args: (0..<args).map { .init(name: "a\($0)", type: "number", required: true, note: "") },
                                   produces: [.init(channel: "output", kind: "value", what: "v")], usecases: usecases)
    }

    func draft(_ commands: [InterpretationCard.Command], ports: [String] = ["converter/length.py"]) throws -> InterpretationDraft {
        let json: [String: Any] = ["name": "N", "word": "n", "summary": "s", "ports": ports.map { ["path": $0, "how": "port"] }]
        var object = try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: json)) as! [String: Any]
        object["commands"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(commands))
        return try JSONDecoder().decode(InterpretationDraft.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testACommandOnAnUnverifiedUseCaseIsRefused() throws {
        let problems = InterpretationChecks.problems(try draft([command("convert", usecases: ["uc9"])]), archetype: .core, verified: ["uc1"], inventory: inventory)
        XCTAssertTrue(problems.contains { $0.contains("rests on no verified use case") }, "\(problems)")
    }

    func testAPortOutsideTheInventoryIsRefused() throws {
        let problems = InterpretationChecks.problems(try draft([command("convert", usecases: ["uc1"])], ports: ["converter/money.py", ".env"]),
                                                     archetype: .core, verified: ["uc1"], inventory: inventory)
        XCTAssertTrue(problems.contains { $0.contains("converter/money.py") && $0.contains("not a file") })
        XCTAssertTrue(problems.contains { $0.contains(".env") && $0.contains("withheld") })
    }

    func testEachLensKeepsItsSize() throws {
        let three = try draft(["a", "b", "c"].map { command($0, usecases: ["uc1"]) })
        XCTAssertTrue(InterpretationChecks.problems(three, archetype: .core, verified: ["uc1"], inventory: inventory).contains { $0.contains("1 to 2 commands") })
        XCTAssertEqual(InterpretationChecks.problems(three, archetype: .whole, verified: ["uc1"], inventory: inventory), [])
        let wide = try draft([command("convert", usecases: ["uc1"], args: 7)])
        XCTAssertTrue(InterpretationChecks.problems(wide, archetype: .core, verified: ["uc1"], inventory: inventory).contains { $0.contains("six at most") })
    }

    func testOverlapAboveSixtyPercentClashesAndBelowItDoesNot() {
        let whole = [command("convert", usecases: ["uc1", "uc2", "uc3"]), command("table", usecases: ["uc4"]), command("units", usecases: ["uc6"])]
        let core = [command("convert", usecases: ["uc1", "uc2", "uc3"])]
        let copy = [command("convert", usecases: ["uc1", "uc2", "uc3"]), command("table", usecases: ["uc4"])]
        XCTAssertLessThan(Diversity.overlap(core, whole), Diversity.limit)
        XCTAssertNil(Diversity.clash(core, with: [whole]))
        XCTAssertGreaterThan(Diversity.overlap(copy, whole), Diversity.limit)
        XCTAssertEqual(Diversity.clash(copy, with: [whole]), 0)
        XCTAssertEqual(Diversity.clash(copy, with: [core, whole]), 0, "the first card it overlaps")
    }

    func testAPlanIsHeldToTheAgentsLimits() throws {
        var spec = try EngineerPaths.sampleSpec()
        spec.commands[0].usecases = ["uc1"]
        spec.commands[1].usecases = ["uc2"]
        let sample = InventoryReader.read(EngineerPaths.project("py-unit-converter")).inventory
        var problems = PlanChecks.problems(spec, verified: ["uc1", "uc2"], inventory: sample)
        // The sample's evidence and carried file are not this fixture's: those are the only problems.
        XCTAssertTrue(problems.allSatisfy { $0.contains("tipcalc.py") || $0.contains("presets.json") }, "\(problems)")
        spec.commands[0].args.append(ArgumentSpec(name: "people", type: "number"))
        spec.commands[1].args.append(ArgumentSpec(name: "directory", type: "string"))
        spec.units[0].functions[0].returns = "(Double, Double)"
        spec.units.append(UnitContract(unit: "Report", functions: [FunctionSpec(name: "x", returns: "Int")]))
        problems = PlanChecks.problems(spec, verified: ["uc1", "uc2"], inventory: sample)
        XCTAssertTrue(problems.contains { $0.contains("people is a integer in one command and a number") || $0.contains("one name, one type") })
        XCTAssertTrue(problems.contains { $0.contains("directory") })
        XCTAssertTrue(problems.contains { $0.contains("(Double, Double)") })
        XCTAssertTrue(problems.contains { $0.contains("unit Report") })
    }

    func testDerivedArithmeticIsRecomputedAndSourceTestsMustCiteATest() throws {
        let unit = UnitContract(unit: "Conversions", functions: [FunctionSpec(name: "convert", params: [ParameterSpec(name: "value", type: "Double")], returns: "Double")])
        let wrong = VectorSpec(name: "w", function: "convert", args: ["value": 5], expect: 3.2, arithmetic: "5 * 1000 / 1609.344")
        let fromCode = VectorSpec(name: "c", function: "convert", args: ["value": 1], expect: 1, origin: "source-test", evidence: "converter/cli.py:1-3")
        let problems = VectorChecks.problems([wrong, fromCode], unit: unit, inventory: inventory)
        XCTAssertTrue(problems.contains { $0.contains("its arithmetic") }, "\(problems)")
        XCTAssertTrue(problems.contains { $0.contains("not a test file") }, "\(problems)")
        XCTAssertEqual(Arithmetic.evaluate("5 * 1000 / 1609.344") ?? 0, 3.1068559611866697, accuracy: 1e-12)
        XCTAssertEqual(Arithmetic.evaluate("(100 - 32) * 5 / 9") ?? 0, 37.77777777777778, accuracy: 1e-12)
        XCTAssertEqual(VectorChecks.holdingOut([wrong, wrong, wrong, wrong, wrong, wrong]).map { $0.held == true }, [false, false, true, false, false, true])
    }
}
