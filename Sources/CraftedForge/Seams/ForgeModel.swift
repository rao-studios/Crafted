//  WHAT: The model seam: what the forge asks of an on-device model, and nothing about how it runs. The live side
//        (CraftedRuntime over CraftedMLX) keeps one model resident and swaps on `prepare`; ScriptedModel answers
//        from a fixture's script; tests answer from closures.
//  PIN:  ONE RESIDENT. Pipelines batch every image before any coder call and say which role they need with
//        `prepare`, so a designer run swaps once and an engineer run never.
//  PIN:  TEXT IN, TEXT OUT. Structured answers are the forge's own (StructuredAsk: salvage, schema, grounding,
//        repair), so a model that cannot constrain its decoding still serves.

import CraftedCore
import Foundation

public enum ForgeModelRole: String, Codable, Sendable, Equatable {
    case coder
    case vision

    public var kind: ModelKind {
        switch self {
        case .coder: return .coder
        case .vision: return .vision
        }
    }
}

/// One ask. `purpose` names the call ("engineer.card", "designer.look"): the call log, the scripted model and the
/// prompt cache key all read it. `system` is byte-identical within a stage so its prefix caches.
public struct ModelPrompt: Codable, Sendable, Equatable {
    public var purpose: String
    public var system: String
    public var user: String

    public init(purpose: String, system: String, user: String) {
        self.purpose = purpose
        self.system = system
        self.user = user
    }

    public var hash: String { ContentHash.sha256(purpose + "\u{1}" + system + "\u{1}" + user) }
}

public struct ModelBudget: Codable, Sendable, Equatable {
    public var maxTokens: Int
    public var temperature: Double
    public var seconds: Double?
    public var seed: UInt64?

    public init(maxTokens: Int, temperature: Double = 0, seconds: Double? = nil, seed: UInt64? = nil) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.seconds = seconds
        self.seed = seed
    }

    public static let card = ModelBudget(maxTokens: 900, temperature: 0, seconds: 240)
    public static let reduce = ModelBudget(maxTokens: 3000, temperature: 0, seconds: 600)
    public static let interpret = ModelBudget(maxTokens: 2500, temperature: 0.6, seconds: 600)
    public static let unit = ModelBudget(maxTokens: 2500, temperature: 0.2, seconds: 600)
    public static let repair = ModelBudget(maxTokens: 2500, temperature: 0.1, seconds: 600)
    public static let look = ModelBudget(maxTokens: 700, temperature: 0.1, seconds: 180)
    public static let words = ModelBudget(maxTokens: 600, temperature: 0.3, seconds: 180)
}

public enum ModelImage: Sendable, Equatable {
    case file(URL)
    case png(Data)
}

public struct ModelReply: Sendable, Equatable {
    public enum Finish: String, Codable, Sendable { case stop, length, deadline }

    public var text: String
    public var finish: Finish
    public var promptTokens: Int
    public var completionTokens: Int
    public var seconds: Double

    public init(text: String, finish: Finish = .stop, promptTokens: Int = 0, completionTokens: Int = 0, seconds: Double = 0) {
        self.text = text
        self.finish = finish
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.seconds = seconds
    }

    public var tokensPerSecond: Double? { seconds > 0 && completionTokens > 0 ? Double(completionTokens) / seconds : nil }
}

public protocol ForgeModel: Sendable {
    /// Which role is resident now, if any.
    func resident() async -> ForgeModelRole?
    /// Makes `role` resident, unloading the other first. Slow the first time (tens of seconds).
    func prepare(_ role: ForgeModelRole) async throws
    /// Frees whatever is resident.
    func release() async
    /// The run's folder, before its first ask: the scripted model picks its script by it. Live models ignore it.
    func bind(source: URL) async
    func text(_ role: ForgeModelRole, _ prompt: ModelPrompt, _ budget: ModelBudget) async throws -> ModelReply
    /// One picture per turn (Mistral 3 takes no more).
    func look(_ prompt: ModelPrompt, image: ModelImage, _ budget: ModelBudget) async throws -> ModelReply
}

public extension ForgeModel {
    func bind(source: URL) async {}
}
