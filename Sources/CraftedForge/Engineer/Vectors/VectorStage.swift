//  WHAT: What every unit and command is held to before a line is ported: a unit's vectors, from the source's own tests
//        first and derived from its rules after, a third held out of the port's prompt; and each command's canonical
//        call, the input a host sends with no model and the facts its answer must carry.
//  IN:   The plan, the inventory (the evidence lines and the test files, redacted).
//  OUT:  vectors/<Unit>.json, calls/<command>.json.
//  PIN:  FROM THE SOURCE ALONE. A vector is written before the unit's port, from the contract and the source, never from
//        the port: the same model writing both would only agree with itself.

import Foundation

struct VectorStage {
    let context: ForgeContext
    let inventory: Inventory

    var ask: EngineerAsk { EngineerAsk(context: context) }

    func vectors(for unit: UnitContract, brief: ProjectBrief, spec: PortSpec) async throws -> [VectorSpec] {
        var user = brief.prefix + "\n\nThe unit: \(unit.unit)\n\(unit.summary)\nIts contract:\n"
        for function in unit.functions {
            user += "  static func \(function.signature)\n"
            for rule in function.rules { user += "    rule: \(rule)\n" }
        }
        let types = spec.types.filter { unit.namedTypes.contains($0.name) }
        if !types.isEmpty { user += "Types: " + types.map(Self.describe).joined(separator: "; ") + "\n" }
        user += "\nThe source it ports:\n" + Self.evidence(unit.evidence, inventory: inventory)
        let tests = inventory.with(.test).compactMap { file -> String? in
            guard let text = inventory.text(file.path) else { return nil }
            return "--- \(file.path)\n" + SourceText.numbered(SourceText.lines(String(text.prefix(8000))))
        }
        user += "\n\nThe source's tests:\n" + (tests.isEmpty ? "(none: derive every vector from the rules)" : tests.joined(separator: "\n\n"))
        let list = try await ask.object(.vectors, user, as: VectorList.self, budget: .reduce) { list in
            VectorChecks.problems(list.vectors, unit: unit, inventory: inventory)
        }
        return VectorChecks.holdingOut(list.vectors)
    }

    func call(for command: CommandSpec, brief: ProjectBrief, spec: PortSpec) async throws -> CallSpec {
        var user = brief.prefix + "\n\nThe command: \(command.name)\n\(command.summary)\nArguments:\n"
        for argument in command.args {
            user += "  \(argument.name) (\(argument.type)\(argument.required ? ", required" : "")"
                + (argument.values.map { ": " + $0.joined(separator: " | ") } ?? "") + "): \(argument.note)\n"
        }
        user += "It produces: " + command.produces.map { "\($0.kind) \($0.name)" }.joined(separator: ", ") + "\n"
        let units = spec.units.filter { command.uses.contains($0.unit) }
        user += "It calls: " + units.map { $0.unit + " (" + $0.functions.map(\.signature).joined(separator: "; ") + ")" }.joined(separator: "; ")
        let examples = inventory.files.filter { [.doc, .test].contains($0.verdict) }.compactMap { file -> String? in
            inventory.text(file.path).map { "--- \(file.path)\n" + String($0.prefix(3000)) }
        }
        user += "\n\nExamples in the project:\n" + examples.joined(separator: "\n\n")
        return try await ask.object(.calls, user, as: CallSpec.self, budget: .card) { call in call.problems(for: command) }
    }

    static func describe(_ type: DomainType) -> String {
        type.kind == "enum" ? "enum \(type.name) { " + type.cases.joined(separator: ", ") + " }"
            : "struct \(type.name) { " + type.fields.map { "\($0.name): \($0.type)" }.joined(separator: ", ") + " }"
    }

    /// The cited lines, numbered, each under its citation.
    static func evidence(_ citations: [String], inventory: Inventory, widen: Int = 0) -> String {
        citations.compactMap(Evidence.parse).compactMap { evidence -> String? in
            let lines = inventory.lines(evidence.path)
            guard !lines.isEmpty else { return nil }
            let range = evidence.range ?? LineRange(1, lines.count)
            let start = max(1, range.start - widen), end = min(lines.count, range.end + widen)
            return "--- \(evidence.path):\(start)-\(end)\n" + SourceText.numbered(lines, from: start, through: end)
        }.joined(separator: "\n\n")
    }
}
