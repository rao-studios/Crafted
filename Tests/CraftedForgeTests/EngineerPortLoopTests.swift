import CraftedCore
import Foundation
import XCTest
@testable import CraftedForge

/// The port loop climbs the strategy ladder in order, and never spends an attempt twice: no prompt resent, no body
/// recompiled, no strategy kept past a repeated failure. A passing body is promoted into the last good tree.
final class EngineerPortLoopTests: XCTestCase {
    let identity = AgentIdentity.derive(display: "Tip Jar")

    /// A loop over the template's sample with every body stubbed, and the TipMath unit as its task.
    func loop(_ coder: FakeCoder, toolchain: FakeToolchain, events: EventBox = EventBox()) throws -> (PortLoop, PortTask) {
        let context = try EngineerHarness.context(model: coder, toolchain: toolchain, events: events)
        let artefacts = try EngineerHarness.sampleArtefacts(identity: identity, ported: false)
        let tree = WorkTree(run: context.run, template: EngineerPaths.skeleton, identity: identity)
        try tree.rebuild(artefacts)
        let stage = PortStage(context: context, inventory: Inventory(files: []), brief: ProjectBrief(title: "Tips", summary: "Tips."),
                              usecases: [], toolchain: toolchain, tree: tree)
        let unit = try XCTUnwrap(artefacts.spec.unit("TipMath"))
        return (PortLoop(context: context, tree: tree, toolchain: toolchain, budget: 20), stage.task(for: unit, artefacts))
    }

    static func broken(_ message: String, _ salt: Int) -> String {
        "```swift\nimport Foundation\n\npublic enum TipMath: TipMathContract {\n    // BROKEN(\(message)) \(salt)\n}\n```"
    }

    static func strategies(_ events: EventBox) -> [String] {
        events.units.filter { $0.phase == .attempt }.compactMap(\.strategy)
    }

    func testTheLadderIsClimbedInOrderUntilTheUnitIsParked() async throws {
        let counter = Counter()
        let coder = FakeCoder { _ in let n = counter.next(); return Self.broken("cannot find 'x\(n)' in scope", n) }
        let events = EventBox()
        let toolchain = FakeToolchain()
        let (loop, task) = try loop(coder, toolchain: toolchain, events: events)
        let (outcome, _) = try await loop.port(task)
        guard case .parked(let last, let attempts) = outcome else { return XCTFail("every body fails, so the unit is parked") }
        XCTAssertEqual(Self.strategies(events), ["write", "repair", "repair", "repair", "repair", "simplify", "simplify", "reread", "reread",
                                                 "idiom", "idiom", "split", "split", "split"])
        XCTAssertEqual(attempts, 14)
        XCTAssertEqual(last?.rung, "build")
        XCTAssertTrue(events.units.contains { $0.phase == .parked })
        let prompts = await coder.prompts
        XCTAssertEqual(Set(prompts.map(\.hash)).count, prompts.count, "no prompt is sent twice")
        XCTAssertTrue(prompts[1].user.contains("Your last file:") && prompts[1].user.contains("cannot find 'x1' in scope"),
                      "a repair carries the last file and its located diagnostic")
        XCTAssertTrue(prompts.last?.user.contains("The one function to write now") == true, "split asks one function at a time")
    }

    func testARepeatedDiagnosticEndsTheStrategy() async throws {
        let counter = Counter()
        let coder = FakeCoder { _ in Self.broken("cannot convert value of type 'Int' to expected argument type 'Double'", counter.next()) }
        let events = EventBox()
        let (loop, task) = try loop(coder, toolchain: FakeToolchain(), events: events)
        _ = try await loop.port(task)
        let strategies = Self.strategies(events)
        XCTAssertEqual(strategies.filter { $0 == "repair" }.count, 2, "the same failure twice in repair ends repair: \(strategies)")
        XCTAssertEqual(Array(strategies.prefix(4)), ["write", "repair", "repair", "simplify"])
    }

    func testTheSameBodyIsNeverCompiledTwice() async throws {
        let coder = FakeCoder { _ in Self.broken("missing return", 0) }
        let toolchain = FakeToolchain()
        let (loop, task) = try loop(coder, toolchain: toolchain)
        _ = try await loop.port(task)
        let asked = await coder.prompts.count
        XCTAssertGreaterThan(asked, 4)
        // The one body the coder keeps writing is built once; the split strategy composes a second, built once too.
        XCTAssertEqual(toolchain.builds, 2, "one body, one build, however often it comes back")
    }

    func testAKeptMemoryNeverResendsAPrompt() async throws {
        let coder = FakeCoder { prompt in Self.broken("missing return", prompt.hash.count) }
        let (loop, task) = try loop(coder, toolchain: FakeToolchain())
        let (_, memory) = try await loop.port(task)
        let sent = await coder.prompts.count
        _ = try await loop.port(task, guard: memory)
        let prompts = await coder.prompts
        XCTAssertGreaterThanOrEqual(prompts.count, sent)
        XCTAssertEqual(Set(prompts.map(\.hash)).count, prompts.count, "across both rounds, no prompt is sent twice")
        XCTAssertFalse(prompts.dropFirst(sent).contains { $0.hash == prompts[0].hash }, "the first write is never asked again")
    }

    func testAPassingBodyIsPromotedIntoTheLastGoodTree() async throws {
        let body = try String(contentsOf: EngineerPaths.skeleton.appendingPathComponent(SkeletonLayout.logic("TipMath")), encoding: .utf8)
        let coder = FakeCoder { _ in "Here it is.\n```swift\n" + body + "```\n" }
        let toolchain = FakeToolchain()
        let (loop, task) = try loop(coder, toolchain: toolchain)
        let (outcome, _) = try await loop.port(task)
        guard case .passed(let passed, let attempts, let strategy) = outcome else { return XCTFail("the sample's own body passes") }
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(strategy, .write)
        XCTAssertEqual(passed, body)
        XCTAssertEqual(toolchain.tests, 1, "built, then its vectors run")
    }

    func testTheScanAndParseRungsRefuseBeforeAnyBuild() async throws {
        let toolchain = FakeToolchain()
        let (loop, task) = try loop(FakeCoder { _ in "" }, toolchain: toolchain)
        let network = try await loop.climb(task, "import Foundation\nimport Network\npublic enum TipMath: TipMathContract { static let s = URLSession.shared }\n", attempt: 1)
        XCTAssertEqual(network?.rung, "scan")
        XCTAssertTrue(network?.lines.contains { $0.contains("imports Network") } == true)
        XCTAssertTrue(network?.lines.contains { $0.contains("network") } == true)
        let unbalanced = try await loop.climb(task, "import Foundation\npublic enum TipMath: TipMathContract {\n", attempt: 1)
        XCTAssertEqual(unbalanced?.rung, "parse")
        XCTAssertEqual(toolchain.builds, 0)
    }
}

/// A thread-safe counter for fake answers.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
}
