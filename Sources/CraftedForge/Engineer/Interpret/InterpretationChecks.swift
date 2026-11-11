//  WHAT: An interpretation held to what the walk found: every command rests on a verified use case, every file it
//        ports is a file of the inventory, its commands and arguments keep the agent's limits and its lens's size,
//        and it differs enough from the others (Diversity).
//  OUT:  InterpretStage (the structured ask's check; a regenerated card when two overlap).

import Foundation

public enum InterpretationChecks {
    /// How many commands each lens takes.
    public static func commandRange(_ archetype: InterpretationCard.Archetype) -> ClosedRange<Int> {
        switch archetype {
        case .whole: return 2...6
        case .core: return 1...2
        case .material: return 1...4
        }
    }

    public static func problems(_ draft: InterpretationDraft, archetype: InterpretationCard.Archetype, verified: Swift.Set<String>,
                                inventory: Inventory) -> [String] {
        var problems: [String] = []
        let range = commandRange(archetype)
        if !range.contains(draft.commands.count) {
            problems.append("the \(archetype.rawValue) lens takes \(range.lowerBound) to \(range.upperBound) commands, not \(draft.commands.count)")
        }
        var names: Swift.Set<String> = []
        for command in draft.commands {
            if !names.insert(command.name).inserted { problems.append("two commands are called \(command.name)") }
            if !SwiftTypeName.isIdentifier(command.name) || command.name.first?.isUppercase == true {
                problems.append("command \(command.name) is not a lowerCamelCase word")
            }
            let resting = command.usecases.filter { verified.contains($0) }
            if resting.isEmpty {
                problems.append("command \(command.name) rests on no verified use case (verified: \(verified.sorted().joined(separator: ", ")))")
            }
            if command.args.count > 6 { problems.append("command \(command.name) has \(command.args.count) arguments; six at most") }
            for argument in command.args where !ArgumentSpec.types.contains(argument.type) {
                problems.append("argument \(argument.name) of \(command.name) is a \(argument.type): use " + ArgumentSpec.types.sorted().joined(separator: ", "))
            }
            for argument in command.args where argument.type == "choice" && (argument.values ?? []).isEmpty {
                problems.append("argument \(argument.name) of \(command.name) is a choice with no values")
            }
        }
        for port in draft.ports {
            guard let file = inventory.file(port.path) else {
                problems.append("it ports \(port.path), which is not a file of the project"); continue
            }
            if ![.read, .resource].contains(file.verdict) {
                problems.append("it ports \(port.path), which the walk did not read as code or data (\(file.verdict.rawValue))")
            }
        }
        return problems
    }
}
