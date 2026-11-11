import CraftedCore
import Foundation
import XCTest
@testable import CraftedForge

/// A unit whose budget is spent is parked and the person decides: keep trying (a new round), drop the commands that
/// need it (the tree is assembled again without them), or stop.
final class EngineerParkingTests: XCTestCase {
    override func setUpWithError() throws { try EngineerPaths.requireFixtures() }

    let identity = AgentIdentity.derive(display: "Tip Jar")

    /// The sample with a second unit, Rounding, that only `split` uses.
    func artefacts() throws -> PortArtefacts {
        var artefacts = try EngineerHarness.sampleArtefacts(identity: identity, ported: true)
        artefacts.spec.units.append(UnitContract(unit: "Rounding",
                                                 functions: [FunctionSpec(name: "cents", params: [ParameterSpec(name: "amount", type: "Double")], returns: "Double")],
                                                 evidence: ["tipcalc.py:1-5"], summary: "cents"))
        artefacts.spec.commands[1].uses.append("Rounding")
        return artefacts
    }

    func stage(answers: [String], events: EventBox, toolchain: FakeToolchain) throws -> (PortStage, ForgeContext, Decisions) {
        let decisions = Decisions(answers)
        let coder = FakeCoder { prompt in
            "```swift\nimport Foundation\npublic enum Rounding: RoundingContract {\n    // BROKEN(no \(prompt.hash.prefix(8)))\n}\n```"
        }
        let home = CraftedHome(root: try EngineerPaths.temporaryFolder("engineer-home"))
        let run = RunFolder(root: home.root.appendingPathComponent("run", isDirectory: true))
        try run.create()
        let context = ForgeContext(id: "park", role: .engineer, source: EngineerPaths.project("py-unit-converter"), run: run,
                                   options: ForgeOptions(unitAttempts: 6, install: false), model: coder, toolchain: toolchain,
                                   templates: TemplateSource(root: EngineerPaths.templates), home: home,
                                   sink: { events.add($0) }, decider: { try await decisions.answer($0) }, chooser: { _, _ in .pick(0) })
        let tree = WorkTree(run: run, template: EngineerPaths.skeleton, identity: identity)
        try tree.rebuild(try artefacts())
        return (PortStage(context: context, inventory: Inventory(files: []), brief: ProjectBrief(title: "Tips", summary: "Tips."), usecases: [],
                          toolchain: toolchain, tree: tree), context, decisions)
    }

    func testAParkedUnitDroppedTakesOnlyTheCommandsThatNeedIt() async throws {
        let events = EventBox()
        let (stage, context, decisions) = try stage(answers: ["drop"], events: events, toolchain: FakeToolchain())
        let ported = try await stage.portUnits(try artefacts())
        let asked = await decisions.asked
        XCTAssertEqual(asked.map(\.kind), [.unitParked])
        XCTAssertEqual(asked.first?.defaultOption, "drop")
        XCTAssertEqual(Set(asked.first?.options.map(\.id) ?? []), ["keep", "drop", "stop"])
        XCTAssertEqual(ported.state.dropped.map(\.command), ["split"])
        XCTAssertEqual(ported.shipped.commands.map(\.name), ["tip"])
        XCTAssertEqual(ported.shipped.units.map(\.unit), ["TipMath"])
        XCTAssertTrue(events.units.contains { $0.unit == "split" && $0.phase == .dropped })
        let package = context.run.workPackage
        XCTAssertFalse(FileManager.default.fileExists(atPath: package.appendingPathComponent("Sources/TipJarAgent/Handlers/SplitHandler.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: package.appendingPathComponent("Sources/TipJarAgent/Surface/SplitArguments.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.appendingPathComponent("Sources/TipJarAgent/Handlers/TipHandler.swift").path))
        XCTAssertEqual(context.run.read(PortState.self, "port.json")?.dropped.map(\.command), ["split"], "the drop is kept in the run")
        let verification = ported.state.verification(ported.spec)
        XCTAssertEqual(verification.count, 1, "a dropped command is never said to be verified")
    }

    func testKeepTryingStartsANewRoundWithNewPrompts() async throws {
        let events = EventBox()
        let (stage, _, decisions) = try stage(answers: ["keep", "drop"], events: events, toolchain: FakeToolchain())
        let ported = try await stage.portUnits(try artefacts())
        let asked = await decisions.asked
        XCTAssertEqual(asked.map(\.id), ["unitParked-Rounding-1", "unitParked-Rounding-2"])
        XCTAssertEqual(events.units.filter { $0.phase == .started && $0.unit == "Rounding" }.count, 2)
        XCTAssertEqual(ported.state.dropped.map(\.command), ["split"])
    }

    func testStopEndsTheRun() async throws {
        let (stage, _, _) = try stage(answers: ["stop"], events: EventBox(), toolchain: FakeToolchain())
        do {
            _ = try await stage.portUnits(try artefacts())
            XCTFail("stop ends the run")
        } catch let error as ForgeError {
            XCTAssertTrue(error.localizedDescription.contains("stopped at Rounding"), error.localizedDescription)
        }
    }
}

/// The person's answers, in order, and the decisions they were asked.
actor Decisions {
    private var answers: [String]
    private(set) var asked: [Decision] = []

    init(_ answers: [String]) { self.answers = answers }

    func answer(_ decision: Decision) -> DecisionAnswer {
        asked.append(decision)
        return DecisionAnswer(option: answers.isEmpty ? decision.defaultOption : answers.removeFirst())
    }
}
