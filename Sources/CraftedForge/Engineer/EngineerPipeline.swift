//  WHAT: An engineer's project into an agent: inventory, walk (brief and cards), reduce (domain, use cases, the
//        second look), three interpretations and the person's choice, the plan, the tree built with every body stubbed,
//        vectors and canonical calls from the source, the port of every unit and handler, the listing's words, and the
//        package's own gates. See the plan's "Engineer framework".
//  IN:   A ForgeContext: the dropped folder, the coder (live or scripted), a Swift toolchain, the run folder.
//  OUT:  The run's artefacts (inventory.json, brief.json, cards.json, usecases.json, interpretations.json, plan.json,
//        vectors/, calls/, slots/, port.json, project.json, words.json) and the last good tree in work/package; the
//        outcome (listing, gates). `assemble` makes a clean package from the artefacts alone.
//  PIN:  HONEST. Nothing ships stubbed: a unit that cannot be ported is parked, and a command dropped is said in the
//        README and the report. No toolchain, no port: every unit is checked by `swift build` and its vectors.

import CraftedCore
import Foundation

public struct EngineerPipeline: RolePipeline {
    public init() {}

    public var role: CraftedRole { .engineer }

    public var stages: [ForgeStage] {
        [
            ForgeStage(id: "inventory", title: "Listing the project", part: .analysis, weight: 0.5),
            ForgeStage(id: "walk", title: "Reading every file", part: .analysis, weight: 6),
            ForgeStage(id: "reduce", title: "Finding the use cases", part: .analysis, weight: 3),
            ForgeStage(id: "interpret", title: "Imagining three agents", part: .analysis, weight: 2),
            ForgeStage(id: "plan", title: "Planning the port", part: .generation, weight: 1.5),
            ForgeStage(id: "scaffold", title: "Building the frame", part: .generation, weight: 1.5),
            ForgeStage(id: "vectors", title: "Writing what it is held to", part: .generation, weight: 2),
            ForgeStage(id: "port", title: "Porting the logic", part: .generation, weight: 8),
            ForgeStage(id: "handlers", title: "Wiring the commands", part: .generation, weight: 3),
            ForgeStage(id: "words", title: "Naming it", part: .generation, weight: 0.5),
            ForgeStage(id: "gates", title: "Testing and installing", part: .generation, weight: 2),
        ]
    }

    public func generate(_ context: ForgeContext) async throws -> PipelineOutcome {
        guard let toolchain = context.toolchain, await toolchain.version() != nil else {
            throw ForgeError.noToolchain("the engineer role ports a project to Swift and checks every unit with swift build: install Xcode or the Swift toolchain, then resume")
        }
        let template = context.templates.folder(.engineer)
        _ = try TemplateManifest.read(template)
        let folder = context.source.lastPathComponent

        // Inventory.
        context.started("inventory")
        let read = InventoryReader.read(context.source)
        let inventory = read.inventory
        for finding in read.findings { context.finding(finding) }
        try context.run.write(inventory, "inventory.json")
        let secrets = read.findings.filter { $0.kind == .secret }
        if !secrets.isEmpty {
            let answer = try await context.decide(Decision(
                id: "secretsFound", kind: .secretsFound,
                question: "\(secrets.count) secret\(secrets.count == 1 ? "" : "s") were found and redacted before anything was read. Go on?",
                detail: secrets.map(\.text), options: [Decision.Option(id: "go", title: "Go on, redacted"), Decision.Option(id: "stop", title: "Stop")],
                defaultOption: "go"))
            if answer.option == "stop" { throw ForgeError.stage("Inventory", "stopped: secrets were found in the project") }
        }
        let sources = inventory.with(.read)
        guard !sources.isEmpty else { throw ForgeError.stage("Inventory", "the folder holds no source code the walk can read") }
        context.finished("inventory", "\(inventory.files.count) files: \(sources.count) read as code, \(inventory.with(.withheld).count) withheld")

        // Walk.
        context.started("walk")
        let walk = WalkStage(context: context, inventory: inventory)
        let brief = try await walk.brief()
        try context.run.write(brief, "brief.json")
        let graph = ImportGraph.of(inventory)
        let cards = try await walk.cards(brief: brief, order: graph.order, graph: graph)
        try context.run.write(cards, "cards.json")
        context.finished("walk", "\(cards.count) files carded")

        // Reduce.
        context.started("reduce")
        let reduce = ReduceStage(context: context, inventory: inventory)
        let modules = ModuleMap.of(graph)
        try context.run.write(modules, "modules.json")
        let domain = try await reduce.domain(brief: brief, cards: cards, modules: modules)
        try context.run.write(domain, "domain.json")
        var usecases = try await reduce.usecases(brief: brief, domain: domain, cards: cards)
        usecases = try await reduce.verify(usecases, brief: brief)
        try context.run.write(usecases, "usecases.json")
        let verified = usecases.filter(\.verified)
        guard !verified.isEmpty else {
            _ = try await context.decide(Decision(id: "nothingPortable", kind: .nothingPortable,
                                                  question: "No use case of this project could be verified against its own lines, so nothing can be ported.",
                                                  options: [Decision.Option(id: "stop", title: "Stop")], defaultOption: "stop"))
            throw ForgeError.stage("Reduce", "no use case could be verified, so nothing can be ported")
        }
        context.progress("reduce", "\(verified.count) of \(usecases.count) use cases verified", fraction: 1, counts: ["useCases": usecases.count])
        context.finished("reduce", "\(usecases.count) use cases, \(verified.count) verified")

        // Interpret, and the person's choice.
        context.started("interpret")
        let card = try await choose(context, inventory: inventory, brief: brief, usecases: usecases)
        context.finished("interpret", "Chose \(card.name)")

        // Plan.
        context.started("plan")
        let planner = PlanStage(context: context, inventory: inventory)
        let spec = try await planner.plan(brief: brief, card: card, usecases: usecases, cards: cards)
        try context.run.write(spec, "plan.json")
        try context.run.write(["commands": spec.commands], "commands.json")
        try context.run.write(["units": spec.units], "units.json")
        try planner.carry(spec, project: folder)
        let identity = context.run.read(PortState.self, "port.json")?.identity ?? AgentIdentity.derive(display: card.name, word: card.word)
        try context.run.write(ProjectRecord(folder: folder, title: brief.title, licence: inventory.licence, card: card,
                                            files: Dictionary(inventory.files.map { ($0.path, $0.verdict.rawValue) }, uniquingKeysWith: { first, _ in first })),
                              "project.json")
        if context.run.read(PortState.self, "port.json") == nil { try context.run.write(PortState(identity: identity), "port.json") }
        var artefacts = try PortArtefacts.load(context.run)
        context.finished("plan", "\(spec.commands.count) commands, \(spec.units.count) units")

        // Scaffold: every body stubbed, and it builds.
        let tree = WorkTree(run: context.run, template: template, identity: identity)
        let port = PortStage(context: context, inventory: inventory, brief: brief, usecases: usecases, toolchain: toolchain, tree: tree)
        context.started("scaffold")
        artefacts = try await port.scaffold(artefacts)
        context.finished("scaffold", "The frame builds with every body stubbed")

        // Vectors and canonical calls, from the source alone.
        context.started("vectors")
        artefacts = try await port.vectors(artefacts)
        let count = artefacts.vectors.values.reduce(0) { $0 + $1.vectors.count }
        context.finished("vectors", "\(count) vectors, \(artefacts.calls.count) canonical calls")

        // The port: units, then handlers.
        context.started("port")
        artefacts = try await port.portUnits(artefacts)
        context.finished("port", "\(artefacts.shipped.units.count) units ported" + (artefacts.state.dropped.isEmpty ? "" : ", \(artefacts.state.dropped.count) commands dropped"))
        context.started("handlers")
        artefacts = try await port.portHandlers(artefacts)
        context.finished("handlers", "\(artefacts.shipped.commands.count) commands answer their canonical calls"
                         + (artefacts.state.dropped.isEmpty ? "" : ", \(artefacts.state.dropped.count) dropped"))

        // Words.
        context.started("words")
        let listing = try await WordsStage(context: context, inventory: inventory).listing(brief: brief, card: card, spec: artefacts.shipped, identity: identity)
        context.emit(.listing(listing))
        context.finished("words", listing.name)

        // Gates.
        context.started("gates")
        let gates = await EngineerGates(context: context, toolchain: toolchain, tree: tree).run(artefacts)
        let passed = gates.filter(\.passed).count
        context.finished("gates", "\(passed) of \(gates.count) gates passed")

        var notes = artefacts.state.verification(artefacts.spec)
        notes += artefacts.state.dropped.map { "Dropped \($0.command): \($0.why)." }
        return PipelineOutcome(listing: listing, summary: artefacts.shipped.summary, interpretation: card.name, gates: gates, notes: notes)
    }

    /// Three cards, the person's pick or steer, round after round until a pick.
    func choose(_ context: ForgeContext, inventory: Inventory, brief: ProjectBrief, usecases: [UseCase]) async throws -> InterpretationCard {
        if let kept = context.ledger.get(InterpretationCard.self, "chosen") { return kept }
        let stage = InterpretStage(context: context, inventory: inventory)
        var steer: [String] = []
        var rounds: [[InterpretationCard]] = []
        while true {
            let cards = try await stage.cards(brief: brief, usecases: usecases, steer: steer)
            rounds.append(cards)
            try context.run.write(rounds, "interpretations.json")
            switch try await context.choose(cards, round: rounds.count) {
            case .pick(let index):
                let card = cards[min(max(index, 0), cards.count - 1)]
                try? context.ledger.put(card, "chosen")
                return card
            case .steer(let words):
                steer.append(words)
            }
        }
    }

    public func assemble(_ request: AssemblyRequest) async throws -> AssembledPackage {
        let artefacts = try PortArtefacts.load(request.run)
        guard let project = request.run.read(ProjectRecord.self, "project.json") else { throw ForgeError.notFound("The port's project record (project.json)") }
        let template = request.templates.folder(.engineer)
        let identity = request.identity
        let readme = ReadmeWriter.text(identity: identity, listing: request.listing, artefacts: artefacts, project: project)
        let notice = NoticeWriter.text(identity: identity, listing: request.listing, project: project)
        let extra = ["README.md": Data(readme.utf8), "NOTICE": Data(notice.utf8)]
        let plan = try EngineerAssembly.plan(template: template, identity: identity, artefacts: artefacts, extra: extra)
        var tree = try PackageAssembler.assemble(plan, into: request.destination)
        let provenance = ProvenanceWriter.text(identity: identity, tree: tree, plan: plan, artefacts: artefacts, project: project, template: template)
        try AtomicFile.write(provenance, to: request.destination.appendingPathComponent("PROVENANCE.md"))
        tree.files = (tree.files + ["PROVENANCE.md"]).sorted()
        let leftOut = project.card.leavesOut.map { "\($0.what): \($0.why)" } + artefacts.state.dropped.map { "\($0.command) (dropped): \($0.why)" }
        let stubs = tree.files.filter { $0.hasSuffix(".swift") }.filter { file in
            (try? String(contentsOf: request.destination.appendingPathComponent(file), encoding: .utf8)).map(SkeletonCodegen.isStub) ?? false
        }
        guard stubs.isEmpty else {
            throw ForgeError.gate("The package still holds stubs (\(stubs.joined(separator: ", "))): nothing ships stubbed. Resume the run to finish the port.")
        }
        return AssembledPackage(tree: tree, verification: artefacts.state.verification(artefacts.spec), leftOut: leftOut,
                                notes: ["Ported from \(project.title) as \"\(project.card.name)\"."])
    }
}
