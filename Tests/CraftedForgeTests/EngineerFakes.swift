import CraftedCore
import Foundation
@testable import CraftedForge

/// A coder that answers from a closure, and remembers every prompt it was sent.
actor FakeCoder: ForgeModel {
    private let answer: @Sendable (ModelPrompt) -> String
    private(set) var prompts: [ModelPrompt] = []

    init(_ answer: @escaping @Sendable (ModelPrompt) -> String) { self.answer = answer }

    func resident() async -> ForgeModelRole? { .coder }
    func prepare(_ role: ForgeModelRole) async throws {}
    func release() async {}

    func text(_ role: ForgeModelRole, _ prompt: ModelPrompt, _ budget: ModelBudget) async throws -> ModelReply {
        prompts.append(prompt)
        return ModelReply(text: answer(prompt))
    }

    func look(_ prompt: ModelPrompt, image: ModelImage, _ budget: ModelBudget) async throws -> ModelReply {
        prompts.append(prompt)
        return ModelReply(text: answer(prompt))
    }
}

/// A toolchain with no compiler: a tree "builds" unless one of its Swift files holds `BROKEN(<message>)`, and its
/// tests pass unless one holds `FAILS(<message>)`. It counts what it was asked.
final class FakeToolchain: ForgeToolchain, @unchecked Sendable {
    private let lock = NSLock()
    private var _builds = 0
    private var _tests = 0
    var builds: Int { lock.withLock { _builds } }
    var tests: Int { lock.withLock { _tests } }

    func version() async -> String? { "Swift 6.4 (fake)" }

    func build(package: URL, target: String?, scratch: URL) async throws -> BuildResult {
        lock.withLock { _builds += 1 }
        let marked = Self.marked(package, "BROKEN")
        return BuildResult(succeeded: marked.isEmpty, diagnostics: marked.map {
            Diagnostic(file: $0.file, line: $0.line, column: 1, severity: .error, message: $0.message)
        })
    }

    func test(package: URL, filter: String?, scratch: URL) async throws -> TestResult {
        lock.withLock { _tests += 1 }
        let broken = Self.marked(package, "BROKEN")
        if !broken.isEmpty {
            return TestResult(succeeded: false, diagnostics: broken.map { Diagnostic(file: $0.file, line: $0.line, column: 1, severity: .error, message: $0.message) })
        }
        let failing = Self.marked(package, "FAILS")
        return TestResult(succeeded: failing.isEmpty, passed: failing.isEmpty ? 3 : 1,
                          failures: failing.map { TestResult.Failure(test: "VectorTests.test", message: "vector \"x\": \($0.message)") })
    }

    func install(package: URL, shelf: URL) async throws -> InstalledAgent {
        InstalledAgent(name: package.lastPathComponent, folder: shelf, executable: shelf.appendingPathComponent("agent"), words: [])
    }

    func describe(_ agent: InstalledAgent) async throws -> Data { Data("[]".utf8) }

    func perform(_ agent: InstalledAgent, word: String, input: Data, directory: URL) async throws -> CallOutcome {
        CallOutcome(output: Data("{}".utf8))
    }

    /// `MARK(message)` occurrences in the tree's Swift files, with where.
    static func marked(_ package: URL, _ mark: String) -> [(file: String, line: Int, message: String)] {
        var found: [(String, Int, String)] = []
        guard let walker = FileManager.default.enumerator(at: package, includingPropertiesForKeys: nil) else { return [] }
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8), text.contains(mark + "(") else { continue }
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                guard let range = line.range(of: mark + "(") else { continue }
                let message = line[range.upperBound...].prefix { $0 != ")" }
                found.append((url.path, index + 1, String(message)))
            }
        }
        return found
    }
}

/// A run's context over a temporary home, the real template, and the fakes.
enum EngineerHarness {
    static func context(model: any ForgeModel, toolchain: (any ForgeToolchain)? = FakeToolchain(), source: URL? = nil,
                        options: ForgeOptions = ForgeOptions(autoDecide: true, autoChoose: 0, unitAttempts: 20, install: false),
                        events: EventBox = EventBox()) throws -> ForgeContext {
        let home = CraftedHome(root: try EngineerPaths.temporaryFolder("engineer-home"))
        let run = RunFolder(root: home.root.appendingPathComponent("run", isDirectory: true))
        try run.create()
        return ForgeContext(id: "test", role: .engineer, source: source ?? EngineerPaths.project("py-unit-converter"), run: run, options: options,
                            model: model, toolchain: toolchain, templates: TemplateSource(root: EngineerPaths.templates), home: home,
                            sink: { events.add($0) },
                            decider: { DecisionAnswer(option: $0.defaultOption) },
                            chooser: { _, _ in .pick(0) })
    }

    /// The template's sample port as a run's artefacts: its plan, and its own slot bodies, vectors and calls.
    static func sampleArtefacts(identity: AgentIdentity, ported: Bool) throws -> PortArtefacts {
        let spec = try EngineerPaths.sampleSpec()
        let skeleton = EngineerPaths.skeleton
        func text(_ path: String) throws -> String { try String(contentsOf: skeleton.appendingPathComponent(path), encoding: .utf8) }
        var artefacts = PortArtefacts(spec: spec, state: PortState(identity: identity))
        artefacts.vectors["TipMath"] = try JSONDecoder().decode(VectorList.self, from: Data(text(SkeletonLayout.vectors("TipMath")).utf8))
        for command in ["tip", "split"] {
            artefacts.calls[command] = try ForgeJSON.decoder.decode(CallSpec.self, from: Data(text(SkeletonLayout.call(command)).utf8))
        }
        artefacts.carried["tip-presets.json"] = CarriedText(source: "presets.json", text: try text(SkeletonLayout.resource("tip-presets.json")))
        if ported {
            artefacts.state.ported = ["TipMath", SkeletonCodegen.handlerKey("tip"), SkeletonCodegen.handlerKey("split")]
            for path in [SkeletonLayout.logic("TipMath"), SkeletonLayout.handler("tip"), SkeletonLayout.handler("split")] {
                artefacts.slots[path] = try text(path)
            }
        }
        return artefacts
    }
}

/// Events a test context said, in order.
final class EventBox: @unchecked Sendable {
    private let lock = NSLock()
    private var list: [ForgeEvent] = []

    func add(_ event: ForgeEvent) { lock.withLock { list.append(event) } }
    var events: [ForgeEvent] { lock.withLock { list } }

    var units: [UnitEvent] { events.compactMap { if case .unit(let unit) = $0 { return unit } else { return nil } } }
}
