//  WHAT: The designer pipeline's model asks: each purpose (what the call log, the scripted model and the cache key
//        read), its system prompt (a resource, versioned in its file name), and the budget it is asked under.
//
//        designer.look                 vision, one piece a turn → Observation
//        designer.synth.colour         coder → ColourAnswer
//        designer.synth.type           coder → TypeAnswer
//        designer.synth.layout         coder → LayoutAnswer
//        designer.synth.imagery        coder → ImageryAnswer
//        designer.synth.voice          coder → VoiceAnswer
//        designer.words                coder → WordsAnswer
//
//  PIN:  A NEW PROMPT IS A NEW FILE. Changing a prompt means writing designer.look.v2.md and moving `version`, so
//        every cached answer from the old one misses.

import Foundation

public enum DesignerPrompts {
    public static let version = "v1"

    public enum Purpose: String, CaseIterable, Sendable {
        case look = "designer.look"
        case colour = "designer.synth.colour"
        case type = "designer.synth.type"
        case layout = "designer.synth.layout"
        case imagery = "designer.synth.imagery"
        case voice = "designer.synth.voice"
        case words = "designer.words"
    }

    /// The system prompt for `purpose`, from the forge's resources.
    public static func system(_ purpose: Purpose) throws -> String {
        let path = "Prompts/\(purpose.rawValue).\(version).md"
        guard let text = ForgeResources.text(path) else { throw ForgeError.template("the prompt \(path) is missing from the forge's resources") }
        return text
    }

    public static func prompt(_ purpose: Purpose, user: String) throws -> ModelPrompt {
        ModelPrompt(purpose: purpose.rawValue, system: try system(purpose), user: user)
    }

    public static let synthesis = ModelBudget(maxTokens: 900, temperature: 0.2, seconds: 300)
}
