//  WHAT: The port, in the plan's order: the tree assembled with every body a stub and built ("skeleton green"); the
//        vectors and canonical calls written from the source; then each logic unit, leaves first, and each command's
//        handler, through the port loop. A unit that cannot be ported is parked and the person decides: keep trying,
//        drop the commands that need it, or stop.
//  IN:   The plan (PortArtefacts), the inventory, the brief, a toolchain.
//  OUT:  port.json after every step, slots/, vectors/, calls/; the last good tree in work/package.
//  PIN:  NOTHING SHIPS STUBBED. A command is ported whole or dropped and said in the README; its tree never holds a stub
//        once the loop has ended.

import CraftedCore
import Foundation

struct PortStage {
    let context: ForgeContext
    let inventory: Inventory
    let brief: ProjectBrief
    let usecases: [UseCase]
    let toolchain: any ForgeToolchain
    let tree: WorkTree

    var budget: Int { max(context.options.unitAttempts, 4) }

    /// The tree with every body a stub, built.
    func scaffold(_ artefacts: PortArtefacts) async throws -> PortArtefacts {
        var artefacts = artefacts
        context.progress("scaffold", "Writing the surface, contracts and stubs")
        try tree.rebuild(artefacts)
        context.progress("scaffold", "Building the tree with every body stubbed", fraction: 0.4)
        let build = try await toolchain.build(package: tree.package, target: nil, scratch: context.run.buildScratch)
        guard build.succeeded else {
            let lines = build.errors.prefix(6).map { "\(($0.file as NSString).lastPathComponent):\($0.line): \($0.message)" }
            throw ForgeError.stage("Scaffold", "the generated tree does not build, so nothing can be ported: " + lines.joined(separator: "; "))
        }
        artefacts.state.green = true
        try context.run.write(artefacts.state, "port.json")
        return artefacts
    }

    /// Each unit's vectors and each command's canonical call, from the source.
    func vectors(_ artefacts: PortArtefacts) async throws -> PortArtefacts {
        var artefacts = artefacts
        let stage = VectorStage(context: context, inventory: inventory)
        let spec = artefacts.shipped
        let total = spec.units.count + spec.commands.count
        for (index, unit) in spec.units.enumerated() where artefacts.vectors[unit.unit] == nil {
            try context.checkCancellation()
            context.progress("vectors", "Vectors for \(unit.unit)", fraction: Double(index) / Double(max(total, 1)))
            let list = VectorList(unit: unit.unit, vectors: try await stage.vectors(for: unit, brief: brief, spec: spec))
            try context.run.write(list, "vectors/\(unit.unit).json")
            artefacts.vectors[unit.unit] = list
        }
        for (index, command) in spec.commands.enumerated() where artefacts.calls[command.name] == nil {
            try context.checkCancellation()
            context.progress("vectors", "The canonical call of \(command.name)", fraction: Double(spec.units.count + index) / Double(max(total, 1)))
            let call = try await stage.call(for: command, brief: brief, spec: spec)
            try context.run.write(call, "calls/\(command.name).json")
            artefacts.calls[command.name] = call
        }
        try tree.rebuild(artefacts)
        return artefacts
    }

    /// Every logic unit, leaves first; parked ones decided.
    func portUnits(_ artefacts: PortArtefacts) async throws -> PortArtefacts {
        var artefacts = artefacts
        let loop = PortLoop(context: context, tree: tree, toolchain: toolchain, budget: budget)
        let units = PlanChecks.order(artefacts.shipped.units)
        for (index, unit) in units.enumerated() {
            guard artefacts.shipped.unit(unit.unit) != nil, !artefacts.state.ported.contains(unit.unit) else { continue }
            context.progress("port", "Porting \(unit.unit)", fraction: Double(index) / Double(max(units.count, 1)),
                             counts: ["units": units.count, "unitsPassed": artefacts.state.ported.filter { !$0.hasPrefix("handler:") }.count])
            artefacts = try await settle(task(for: unit, artefacts), key: unit.unit, artefacts: artefacts, loop: loop)
        }
        return artefacts
    }

    /// Every command's handler, held to its canonical call; parked ones decided.
    func portHandlers(_ artefacts: PortArtefacts) async throws -> PortArtefacts {
        var artefacts = artefacts
        let loop = PortLoop(context: context, tree: tree, toolchain: toolchain, budget: budget)
        let commands = artefacts.shipped.commands
        for (index, command) in commands.enumerated() {
            let key = SkeletonCodegen.handlerKey(command.name)
            guard artefacts.shipped.commands.contains(where: { $0.name == command.name }), !artefacts.state.ported.contains(key) else { continue }
            context.progress("handlers", "The handler of \(command.name)", fraction: Double(index) / Double(max(commands.count, 1)),
                             counts: ["units": commands.count, "unitsPassed": artefacts.state.ported.filter { $0.hasPrefix("handler:") }.count])
            artefacts = try await settle(task(for: command, artefacts), key: key, artefacts: artefacts, loop: loop)
        }
        return artefacts
    }

    /// Ports `task` until it passes, or the person drops it or stops.
    func settle(_ task: PortTask, key: String, artefacts: PortArtefacts, loop: PortLoop) async throws -> PortArtefacts {
        var artefacts = artefacts
        var memory = ThrashGuard()
        var round = 1
        while true {
            let (outcome, kept) = try await loop.port(task, round: round, guard: memory)
            memory = kept
            switch outcome {
            case .passed(let body, let attempts, let strategy):
                try tree.promote(task.templatePath, body)
                try context.run.write(SlotBody(path: task.templatePath, text: body, by: "\(task.name) · \(strategy.rawValue) · attempt \(attempts)"),
                                      SlotBody.artefact(task.templatePath))
                artefacts.slots[task.templatePath] = body
                artefacts.state.ported.append(key)
                let list = artefacts.vectors[task.name]?.vectors ?? []
                artefacts.state.records[key] = PortState.Record(
                    status: "passed", attempts: attempts, strategy: strategy.rawValue,
                    sourceVectors: list.filter { $0.origin == "source-test" }.count, derivedVectors: list.filter { $0.origin == "derived" }.count,
                    heldOut: list.filter { $0.held == true }.count)
                try context.run.write(artefacts.state, "port.json")
                return artefacts
            case .parked(let last, let attempts):
                let affected = commands(needing: task, in: artefacts.shipped)
                let decision = Decision(
                    id: "unitParked-\(key)-\(round)", kind: .unitParked,
                    question: "\(task.name) did not port in \(attempts) tries. Keep trying, drop \(affected.joined(separator: ", ")), or stop?",
                    detail: last?.lines ?? [],
                    options: [Decision.Option(id: "keep", title: "Keep trying", detail: "Another round of every strategy."),
                              Decision.Option(id: "drop", title: "Drop \(affected.joined(separator: ", "))", detail: "The agent ships without it; the README says so."),
                              Decision.Option(id: "stop", title: "Stop", detail: "End the run; it can be resumed.")],
                    defaultOption: "drop")
                let answer = try await context.decide(decision)
                switch answer.option {
                case "keep":
                    round += 1
                case "stop":
                    throw ForgeError.stage("Port", "stopped at \(task.name), as asked")
                default:
                    let why = "\(task.name) did not port in \(attempts) tries" + (last.map { ": " + ($0.lines.first ?? $0.rung) } ?? "")
                    for command in affected where !artefacts.state.droppedNames.contains(command) {
                        artefacts.state.dropped.append(PortState.Dropped(command: command, why: why))
                        context.emit(.unit(UnitEvent(unit: command, phase: .dropped, detail: why)))
                    }
                    artefacts.state.records[key] = PortState.Record(status: "dropped", attempts: attempts)
                    try context.run.write(artefacts.state, "port.json")
                    guard !artefacts.shipped.commands.isEmpty else {
                        throw ForgeError.stage("Port", "every command was dropped, so there is nothing to ship: " + why)
                    }
                    try tree.rebuild(artefacts)
                    return artefacts
                }
            }
        }
    }

    /// The commands that cannot ship without `task`.
    func commands(needing task: PortTask, in spec: PortSpec) -> [String] {
        if task.kind == .handler { return [task.name] }
        var needing: Swift.Set<String> = [task.name]
        var grew = true
        while grew {
            grew = false
            for unit in spec.units where !needing.contains(unit.unit) && unit.calls.contains(where: needing.contains) {
                needing.insert(unit.unit); grew = true
            }
        }
        return spec.commands.filter { $0.uses.contains(where: needing.contains) }.map(\.name)
    }

    // MARK: Tasks

    func task(for unit: UnitContract, _ artefacts: PortArtefacts) -> PortTask {
        let spec = artefacts.shipped
        var contract = CoreCodegen.contract(unit)
        for type in spec.types where unit.namedTypes.contains(type.name) { contract += "\n" + CoreCodegen.domain(type) }
        let callable = spec.units.filter { unit.calls.contains($0.unit) }
        if !callable.isEmpty {
            contract += "\nUnits it may call: " + callable.map { other in other.unit + " (" + other.functions.map { "\(other.unit).\($0.signature)" }.joined(separator: "; ") + ")" }.joined(separator: "; ")
        }
        if !unit.resources.isEmpty { contract += "\nCarried tables it reads with CoreResources: " + unit.resources.joined(separator: ", ") }
        contract += "\nDeclare: public enum \(unit.unit): \(unit.contractName) { … }"
        let vectors = artefacts.vectors[unit.unit]?.vectors ?? []
        return PortTask(kind: .unit, name: unit.unit, declares: unit.unit, templatePath: SkeletonLayout.logic(unit.unit), functions: unit.functions,
                        contract: contract, source: VectorStage.evidence(unit.evidence, inventory: inventory),
                        widerSource: VectorStage.evidence(unit.evidence, inventory: inventory, widen: 40),
                        shown: vectors.filter { $0.held != true }.map(\.line), hazards: hazards(unit.evidence), brief: brief.prefix,
                        target: SkeletonLayout.coreTarget, filter: SkeletonLayout.vectorFilter(unit.unit))
    }

    func task(for command: CommandSpec, _ artefacts: PortArtefacts) -> PortTask {
        let spec = artefacts.shipped
        let name = SwiftText.pascal(command.name)
        var contract = SurfaceCodegen.arguments(command, spec: spec)
        contract += "\nDeclare:\nenum \(name)Handler: CommandHandler {\n    static func run(_ arguments: \(name)Arguments, _ kit: CommandKit) async throws -> [Product]\n}\n"
        contract += "\nIt must produce: " + command.produces.map { "\($0.kind) \"\($0.name)\"" }.joined(separator: ", ")
        contract += " (presented as \(command.present) unless the call says otherwise).\n"
        for unit in spec.units where command.uses.contains(unit.unit) { contract += "\n" + CoreCodegen.contract(unit) }
        let citations = usecases.filter { command.usecases.contains($0.id) }.flatMap(\.evidence).map(\.text)
        let call = artefacts.calls[command.name]
        let shown = call.map { call in
            ["input " + JSONValue.object(call.input).compact + (call.expect.map { " → expect " + $0.compact } ?? "")]
        } ?? []
        return PortTask(kind: .handler, name: command.name, declares: name + "Handler", templatePath: SkeletonLayout.handler(command.name),
                        functions: [], contract: contract, source: VectorStage.evidence(citations, inventory: inventory),
                        widerSource: VectorStage.evidence(citations, inventory: inventory, widen: 40), shown: shown,
                        hazards: hazards(citations), brief: brief.prefix, target: SkeletonLayout.agentTarget,
                        filter: SkeletonLayout.callFilter(command.name))
    }

    /// The hazard sheets of the languages `citations` are in.
    func hazards(_ citations: [String]) -> String? {
        let languages = Swift.Set(citations.compactMap(Evidence.parse).compactMap { inventory.file($0.path)?.language })
        let sheets = languages.sorted { $0.rawValue < $1.rawValue }.compactMap(EngineerPrompts.hazards)
        return sheets.isEmpty ? nil : Array(Swift.Set(sheets)).sorted().joined(separator: "\n\n")
    }
}
