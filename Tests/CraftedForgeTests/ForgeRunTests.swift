//  WHAT: A run end to end on a toy pipeline written here: it waits for the person's choice and answer, completes
//        with a package that passes the store and ship gates, and writes the generation's record; a cancel while it
//        waits leaves the generation interrupted.

@testable import CraftedForge
import CraftedCore
import XCTest

final class ForgeRunTests: XCTestCase {
    var home: URL!

    override func setUp() {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("forge-run-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    func forge() -> Forge {
        Forge(model: ScriptedModel(scripts: home), toolchain: nil, templates: TemplateSource(root: home),
              store: GenerationStore(home: CraftedHome(root: home)), pipelines: [ToyPipeline()])
    }

    func testChooseDecideCompleteWritesTheRecord() async throws {
        let forge = forge()
        let source = try StoreFixtures.folder(["tax.py": "def tax(x): return x * 0.2\n"])
        defer { try? FileManager.default.removeItem(at: source) }
        let run = try await forge.start(folder: source, role: .engineer, options: ForgeOptions())
        let seen = Events()
        let reader = Task {
            for await event in run.events {
                seen.add(event)
                switch event {
                case .interpretations(_, let cards): await run.choose(cards.count - 1)
                case .decision(let decision): await run.decide(decision.id, DecisionAnswer(option: "keep"))
                default: break
                }
            }
        }
        await run.start()
        await run.wait()
        await reader.value

        guard case .completed(let report)? = seen.all.last else { return XCTFail("ended with \(String(describing: seen.all.last))") }
        XCTAssertTrue(report.passed, report.gates.map { "\($0.name): \($0.detail)" }.joined(separator: "\n"))
        XCTAssertEqual(report.identity.package, "SalesTaxAgent")
        XCTAssertEqual(report.verification, ["picked Material", "decided keep"])
        XCTAssertTrue(seen.all.contains(.stageStarted("toy")))

        let record = try await waitFor(forge.store) { $0.status == .finished }
        XCTAssertEqual(record.identity?.word, "salestax")
        XCTAssertEqual(record.fraction, 1)
        XCTAssertEqual(record.summary, "A toy.")
        XCTAssertEqual(record.interpretation, "Material")
        let listing = await forge.store.listing(run.id)
        XCTAssertEqual(listing?.tagline, "Adds sales tax.")
        XCTAssertTrue(FileManager.default.fileExists(atPath: forge.store.runURL(run.id).appendingPathComponent("events.jsonl").path))
    }

    func testCancelWhileChoosingLeavesItInterrupted() async throws {
        let forge = forge()
        let source = try StoreFixtures.folder(["a.py": "x = 1\n"])
        defer { try? FileManager.default.removeItem(at: source) }
        let run = try await forge.start(folder: source, role: .engineer, options: ForgeOptions())
        let seen = Events()
        let reader = Task {
            for await event in run.events {
                seen.add(event)
                if case .interpretations = event { await run.cancel() }
            }
        }
        await run.start()
        await run.wait()
        await reader.value
        XCTAssertEqual(seen.all.last, .cancelled)
        _ = try await waitFor(forge.store) { $0.status == .interrupted }
    }

    /// The generation's record once `done` holds (the record keeper writes after the events).
    func waitFor(_ store: GenerationStore, _ done: (Generation) -> Bool) async throws -> Generation {
        for _ in 0..<200 {
            if let record = await store.list().first, done(record) { return record }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let last = await store.list().first
        XCTFail("the record never settled: \(String(describing: last?.status))")
        throw CancellationError()
    }

    final class Events: @unchecked Sendable {
        private let lock = NSLock()
        private var events: [ForgeEvent] = []
        func add(_ event: ForgeEvent) { lock.withLock { events.append(event) } }
        var all: [ForgeEvent] { lock.withLock { events } }
    }
}

/// A pipeline of one stage: asks the person to choose and to decide, keeps both in an artefact, and assembles a
/// package the store takes.
struct ToyPipeline: RolePipeline {
    var role: CraftedRole { .engineer }
    var stages: [ForgeStage] { [ForgeStage(id: "toy", title: "Playing", part: .analysis, weight: 1)] }

    func generate(_ context: ForgeContext) async throws -> PipelineOutcome {
        context.started("toy")
        let cards = InterpretationCard.Archetype.allCases.enumerated().map { index, archetype in
            InterpretationCard(id: index, archetype: archetype, name: archetype.rawValue.capitalized, word: "salestax",
                               summary: "Adds sales tax.", commands: [])
        }
        let choice = try await context.choose(cards, round: 1)
        guard case .pick(let index) = choice else { throw ForgeError.stage("Toy", "no pick") }
        let answer = try await context.decide(Decision(id: "licence", kind: .sourceLicence, question: "Keep it?",
                                                       options: [.init(id: "keep", title: "Keep")], defaultOption: "keep"))
        try context.run.write(["picked \(cards[index].name)", "decided \(answer.option)"], "toy.json")
        context.finished("toy", "played")
        let listing = AgentListing(name: "Sales Tax", word: "salestax", tagline: "Adds sales tax.", category: .data,
                                   keywords: ["tax"], license: .mit)
        return PipelineOutcome(listing: listing, summary: "A toy.", interpretation: cards[index].name)
    }

    func assemble(_ request: AssemblyRequest) async throws -> AssembledPackage {
        let identity = request.identity
        let files = [
            "Package.swift": StoreFixtures.marblePackage.replacingOccurrences(of: "MarbleAgent", with: identity.package),
            "Package.resolved": StoreFixtures.plateResolved,
            "README.md": "# \(identity.display)\n",
            "Sources/\(identity.agentTarget)/\(identity.base)Record.swift":
                "let \(identity.recordName): GraniteRoster.Record = { GraniteRoster.record(\(identity.typeName).self) }\n",
            "Sources/\(identity.agentTarget)/\(identity.typeName).swift": StoreFixtures.agentSource(identity),
        ]
        for (path, text) in files {
            let url = request.destination.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        let kept = request.run.read([String].self, "toy.json") ?? []
        return AssembledPackage(tree: AssembledTree(root: request.destination, files: files.keys.sorted()), verification: kept)
    }
}
