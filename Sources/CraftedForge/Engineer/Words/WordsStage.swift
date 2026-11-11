//  WHAT: The agent's listing, suggested: the coder's name, tagline, keywords and category, held to the store's rules,
//        with the word from the chosen interpretation, the licence the source forces (copyleft stays copyleft), and the
//        fields read off the generated surface.
//  OUT:  words.json; the pipeline's outcome listing, merged under the person's edits by the store.

import CraftedCore
import Foundation

struct WordsStage {
    let context: ForgeContext
    let inventory: Inventory

    var ask: EngineerAsk { EngineerAsk(context: context) }

    func listing(brief: ProjectBrief, card: InterpretationCard, spec: PortSpec, identity: AgentIdentity) async throws -> AgentListing {
        let user = brief.prefix + "\n\nThe agent: \(card.name). \(spec.summary)\nCommands: "
            + spec.commands.map { "\($0.name): \($0.summary)" }.joined(separator: " ")
        let words = try await ask.object(.words, user, as: WordSuggestion.self, budget: .words) { words in
            var problems: [String] = []
            let name = words.name.trimmingCharacters(in: .whitespaces)
            if name.isEmpty || name.count > ListingRules.nameLimit { problems.append("name must be 1 to \(ListingRules.nameLimit) characters") }
            let tagline = words.tagline.trimmingCharacters(in: .whitespaces)
            if tagline.isEmpty || tagline.count > ListingRules.taglineLimit { problems.append("tagline must be 1 to \(ListingRules.taglineLimit) characters") }
            if words.keywords.count > ListingRules.keywordLimit { problems.append("at most \(ListingRules.keywordLimit) keywords") }
            for keyword in words.keywords where !ListingRules.isKeyword(keyword) { problems.append("keyword \"\(keyword)\" is not one the store takes") }
            if ListingCategory(rawValue: words.category) == nil {
                problems.append("category must be one of " + ListingCategory.allCases.map(\.rawValue).joined(separator: ", "))
            }
            return problems
        }
        try? context.run.write(words, "words.json")
        let licence = inventory.licence.flatMap(ListingLicence.init(rawValue:))
        return AgentListing(name: words.name, word: identity.word, tagline: words.tagline,
                            category: ListingCategory(rawValue: words.category) ?? .utilities,
                            keywords: words.keywords.compactMap(ListingRules.keyword(from:)), platforms: ["macOS 26"],
                            license: licence?.isCopyleft == true ? licence! : .mit, fields: Self.fields(spec, word: identity.word))
    }

    /// The agent's inputs as the store shows them: the command, each argument, the shared fields; never `directory`.
    static func fields(_ spec: PortSpec, word: String) -> [ListingField] {
        var fields = [ListingField(name: "command", type: "choice: " + spec.commands.map(\.name).joined(separator: " | "), required: false,
                                   note: "which command to run; left out, the host's model reads one from brief")]
        let required = Swift.Set(spec.commands.count == 1 ? spec.commands[0].args.filter(\.required).map(\.name) : [])
        for field in spec.fields {
            let type = field.type == "choice" ? "choice: " + (field.values ?? []).joined(separator: " | ") : field.type
            fields.append(ListingField(name: field.name, type: type, required: required.contains(field.name), note: field.note))
        }
        for shared in SurfaceCodegen.sharedFields {
            let type = shared.name == "present" ? "choice: output | canvas | context" : (shared.type == "Int" ? "integer" : "string")
            fields.append(ListingField(name: shared.name, type: type, required: false,
                                       note: shared.note.replacingOccurrences(of: "skeletonword", with: word)))
        }
        return fields
    }
}
