//  WHAT: Three ways the project could become an agent, by three questions over the same verified use cases: the whole
//        product, its strongest capability done deeply, and what it knows as material for Canvas and other agents.
//        Each card is checked (InterpretationChecks) and kept apart from the others (Diversity); the person picks one,
//        or says what they want instead, and the three are asked again with their words.
//  OUT:  interpretations.json (every round), the chosen card.
//  PIN:  DIFFERENT BY CONSTRUCTION. Three calls, three questions; a card that overlaps an earlier one by more than 60%
//        is asked again once, told what to differ from.

import CraftedCore
import Foundation

struct InterpretStage {
    let context: ForgeContext
    let inventory: Inventory

    var ask: EngineerAsk { EngineerAsk(context: context) }

    static let lenses: [(InterpretationCard.Archetype, EngineerPrompts.Purpose, String)] = [
        (.whole, .interpretWhole, "Whole: the product as one agent of two to six commands, each a use case a person would call."),
        (.core, .interpretCore, "Core: its strongest single capability as one or two commands, done deeply: every option the source gives it, every edge it handles."),
        (.material, .interpretMaterial, "Material: what the project knows (its tables, rules and formats) prepared as Canvas reports and series, or handed on to other agents: one to four commands."),
    ]

    func cards(brief: ProjectBrief, usecases: [UseCase], steer: [String]) async throws -> [InterpretationCard] {
        let verified = usecases.filter(\.verified)
        let ids = Swift.Set(verified.map(\.id))
        let files = inventory.files.filter { [.read, .resource].contains($0.verdict) }.map { "\($0.path) (\($0.verdict.rawValue), \($0.lines) lines)" }
        var cards: [InterpretationCard] = []
        for (index, lens) in Self.lenses.enumerated() {
            try context.checkCancellation()
            context.progress("interpret", "Imagining the \(lens.0.rawValue) agent", fraction: Double(index) / 3)
            var user = brief.prefix + "\n\nVerified use cases:\n" + verified.map(\.digest).joined(separator: "\n")
                + "\n\nFiles of the inventory:\n" + files.joined(separator: "\n") + "\n\nThe lens: " + lens.2
            for words in steer { user += "\n\nThe person said none of the earlier three fits, and asked for: " + words }
            var draft = try await ask.object(lens.1, user, as: InterpretationDraft.self, budget: .interpret) { draft in
                InterpretationChecks.problems(draft, archetype: lens.0, verified: ids, inventory: inventory)
            }
            if let other = Diversity.clash(draft.commands, with: cards.map(\.commands)) {
                let earlier = cards[other]
                user += "\n\nUnlike: \(earlier.name) already offers " + earlier.commands.map(\.name).joined(separator: ", ")
                    + ". Find a different centre: share at most one command with it."
                let again = try await ask.object(lens.1, user, as: InterpretationDraft.self, budget: .interpret) { draft in
                    InterpretationChecks.problems(draft, archetype: lens.0, verified: ids, inventory: inventory)
                }
                if Diversity.overlap(again.commands, earlier.commands) < Diversity.overlap(draft.commands, earlier.commands) { draft = again }
                if Diversity.clash(draft.commands, with: [earlier.commands]) != nil {
                    context.note("The \(lens.0.rawValue) interpretation still overlaps \(earlier.name); both are offered.")
                }
            }
            var card = draft.card(id: index, archetype: lens.0)
            if card.word.isEmpty || AgentNameRules.wordProblem(card.word) != nil {
                card.word = AgentIdentity.derive(display: card.name).word
            }
            cards.append(card)
        }
        context.progress("interpret", "Three agents to choose from", fraction: 1)
        return cards
    }
}
