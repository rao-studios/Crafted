//  WHAT: An engineer ask through the one path (`context.ask`), kept in a ledger so nothing is asked twice: a resumed
//        run reads its answers back, a card cached by its file's hash serves every generation.
//  PIN:  KEYED BY WHAT THE ANSWER DEPENDS ON. A key holds the purpose, the prompt's version and the prompt's own hash
//        (or, for a card, the file's sha256), so a changed file or an improved prompt misses and nothing else does.

import Foundation

struct EngineerAsk: Sendable {
    let context: ForgeContext

    /// A structured answer, from `ledger` when it has one under `key`.
    func object<T: Codable & Sendable>(_ purpose: EngineerPrompts.Purpose, _ user: String, as type: T.Type, budget: ModelBudget,
                                       ledger: Ledger? = nil, key: String? = nil, repairs: Int = 2,
                                       check: (T) -> [String] = { _ in [] }) async throws -> T {
        let prompt = try EngineerPrompts.prompt(purpose, user: user)
        let store = ledger ?? context.ledger
        let key = key ?? Self.key(purpose, prompt)
        if let kept = store.get(T.self, key) { return kept }
        try await context.use(.coder)
        let value = try await context.ask.object(.coder, prompt, as: type, budget: budget, repairs: repairs, check: check)
        try? store.put(value, key)
        return value
    }

    /// A text answer, kept in the run's ledger by its prompt.
    func text(_ prompt: ModelPrompt, budget: ModelBudget) async throws -> String {
        let key = Self.key(prompt)
        if let kept = context.ledger.get(String.self, key) { return kept }
        try await context.use(.coder)
        let text = try await context.ask.text(.coder, prompt, budget)
        try? context.ledger.put(text, key)
        return text
    }

    static func key(_ purpose: EngineerPrompts.Purpose, _ prompt: ModelPrompt) -> String {
        "\(purpose.rawValue)-\(EngineerPrompts.version)-\(prompt.hash.prefix(24))"
    }

    static func key(_ prompt: ModelPrompt) -> String {
        "\(prompt.purpose)-\(EngineerPrompts.version)-\(prompt.hash.prefix(24))"
    }
}
