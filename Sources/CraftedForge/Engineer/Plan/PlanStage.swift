//  WHAT: The chosen interpretation planned as a port: commands.json, a contract per logic unit, the domain types they
//        name, and the files carried or lifted as they are. Checked by PlanChecks; carried and lifted files are copied
//        into the run (redacted text only) so assembly never reads the dropped folder again.
//  OUT:  plan.json, carried/, lifted/.

import Foundation

struct PlanStage {
    let context: ForgeContext
    let inventory: Inventory

    var ask: EngineerAsk { EngineerAsk(context: context) }

    func plan(brief: ProjectBrief, card: InterpretationCard, usecases: [UseCase], cards: [FileCard]) async throws -> PortSpec {
        let verified = usecases.filter(\.verified)
        let ids = Swift.Set(verified.map(\.id))
        let ported = Swift.Set(card.ports.map(\.path))
        let relevant = cards.filter { ported.isEmpty || ported.contains($0.path) }
        let data = inventory.with(.resource).map { "\($0.path) (\($0.lines) lines)" }
        var user = brief.prefix + "\n\nThe chosen interpretation: \(card.name) (\(card.archetype.rawValue)): \(card.summary)\nCommands:\n"
        for command in card.commands {
            user += "- \(command.name): \(command.summary) [use cases \(command.usecases.joined(separator: ", "))]\n"
            for argument in command.args {
                user += "    \(argument.name) (\(argument.type)\(argument.required ? ", required" : "")): \(argument.note)\n"
            }
            for product in command.produces { user += "    → \(product.channel) \(product.kind): \(product.what)\n" }
        }
        user += "Ports: " + card.ports.map { "\($0.path) (\($0.how))" }.joined(separator: ", ")
        if !card.leavesOut.isEmpty { user += "\nLeaves out: " + card.leavesOut.map { "\($0.what) (\($0.why))" }.joined(separator: "; ") }
        user += "\n\nVerified use cases:\n" + verified.map(\.digest).joined(separator: "\n")
        user += "\n\nCards of the files it ports:\n" + relevant.map(\.digest).joined(separator: "\n")
        user += "\n\nData files that could be carried: " + (data.isEmpty ? "none" : data.joined(separator: ", "))
        return try await ask.object(.plan, user, as: PortSpec.self, budget: .reduce) { spec in
            PlanChecks.problems(spec, verified: ids, inventory: inventory)
        }
    }

    /// The carried and lifted files, written into the run: name → bytes.
    func carry(_ spec: PortSpec, project: String) throws {
        for resource in spec.resources {
            guard let text = inventory.text(resource.source) else { continue }
            try context.run.write(CarriedText(source: resource.source, text: text), "carried/\(resource.name).json")
        }
        for lift in spec.lifts {
            guard let text = inventory.text(lift.source) else { continue }
            let header = "// Lifted by Crafted from \(project)/\(lift.source), as it was. See PROVENANCE.md.\n\n"
            try context.run.write(CarriedText(source: lift.source, text: header + text), "lifted/\(lift.name).json")
        }
    }
}
