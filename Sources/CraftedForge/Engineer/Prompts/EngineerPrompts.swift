//  WHAT: The engineer pipeline's asks: each purpose (what the call log, the scripted model and the caches key on) and
//        its system prompt, read from Resources/Prompts/<purpose>.<version>.md, with the version in the cache keys.
//  OUT:  Every engineer stage.
//  PIN:  ONE SYSTEM PROMPT PER STAGE, BYTE-IDENTICAL. What changes per ask goes in the user turn, so the system
//        prefix caches; a changed prompt file bumps its version, and cached answers keyed by the old one miss.
//
//        engineer.brief           README and manifests → the brief that prefixes every later ask
//        engineer.card            one file (or a chunk of one) → its card
//        engineer.reduce.domain   the cards → nature, kind, entities, glossary
//        engineer.usecases        the cards and domain → use cases with evidence
//        engineer.verify          one use case and only its cited lines → confirmed or corrected
//        engineer.interpret.whole / .core / .material   three lenses → three interpretation cards
//        engineer.plan            the chosen card → commands.json, unit contracts, domain types, carried files
//        engineer.vectors         one unit's contract, evidence and the source's tests → vectors
//        engineer.calls           one command → its canonical call
//        engineer.unit            one unit's contract (and, on a repair, diagnostics) → a Swift file
//        engineer.handler         one command's arguments and units → its handler's Swift file
//        engineer.words           the agent → name, tagline, keywords, category

import Foundation

public enum EngineerPrompts {
    public static let version = "v1"

    public enum Purpose: String, CaseIterable, Sendable {
        case brief = "engineer.brief"
        case card = "engineer.card"
        case domain = "engineer.reduce.domain"
        case usecases = "engineer.usecases"
        case verify = "engineer.verify"
        case interpretWhole = "engineer.interpret.whole"
        case interpretCore = "engineer.interpret.core"
        case interpretMaterial = "engineer.interpret.material"
        case plan = "engineer.plan"
        case vectors = "engineer.vectors"
        case calls = "engineer.calls"
        case unit = "engineer.unit"
        case handler = "engineer.handler"
        case words = "engineer.words"

        /// The resource holding its system prompt: the three lenses share one.
        var resource: String {
            switch self {
            case .interpretWhole, .interpretCore, .interpretMaterial: return "engineer.interpret"
            default: return rawValue
            }
        }
    }

    /// The system prompt for `purpose`.
    public static func system(_ purpose: Purpose) throws -> String {
        let path = "Prompts/\(purpose.resource).\(version).md"
        guard let text = ForgeResources.text(path) else {
            throw ForgeError.template("the forge's prompt \(path) is missing from its resources")
        }
        return text
    }

    /// An ask, its system prompt read for `purpose`.
    public static func prompt(_ purpose: Purpose, user: String) throws -> ModelPrompt {
        ModelPrompt(purpose: purpose.rawValue, system: try system(purpose), user: user)
    }

    /// The hazard sheet for a source language, when there is one.
    public static func hazards(_ language: SourceLanguage) -> String? {
        switch language {
        case .python: return ForgeResources.text("Hazards/python.\(version).md")
        case .javascript, .typescript: return ForgeResources.text("Hazards/javascript.\(version).md")
        default: return nil
        }
    }
}
