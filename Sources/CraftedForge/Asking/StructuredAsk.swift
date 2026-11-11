//  WHAT: The one path every model ask takes: send, log, and for a structured answer read the JSON out of the reply
//        (salvaging a fenced, chatty or truncated one), decode it, check it, and ask again listing what was wrong.
//  IN:   A ForgeModel; the run's calls.jsonl.
//  OUT:  Every stage of both pipelines.
//  PIN:  NEVER THE SAME PROMPT TWICE. A repair carries the problems it is repairing and its round, so it differs
//        from every ask before it; a reply that repeats one already refused stops the repairs early.
//  PIN:  BOUNDED. Two repairs, then a typed failure (`ForgeError.model`) the stage decides what to do with.

import CraftedCore
import Foundation

public struct StructuredAsk: Sendable {
    public let model: any ForgeModel
    public let calls: URL?
    /// Reports tokens per second as replies come back.
    public let onReply: @Sendable (ModelReply) -> Void

    public init(model: any ForgeModel, calls: URL?, onReply: @escaping @Sendable (ModelReply) -> Void = { _ in }) {
        self.model = model
        self.calls = calls
        self.onReply = onReply
    }

    public func text(_ role: ForgeModelRole, _ prompt: ModelPrompt, _ budget: ModelBudget) async throws -> String {
        try Task.checkCancellation()
        let reply = try await model.text(role, prompt, budget)
        log(prompt, reply, outcome: "text")
        onReply(reply)
        return reply.text
    }

    public func look(_ prompt: ModelPrompt, image: ModelImage, _ budget: ModelBudget) async throws -> String {
        try Task.checkCancellation()
        let reply = try await model.look(prompt, image: image, budget)
        log(prompt, reply, outcome: "look")
        onReply(reply)
        return reply.text
    }

    /// An answer of type `T`. `check` returns problems in the answer as sentences (grounding, ranges, names); an
    /// empty list accepts it.
    public func object<T: Decodable & Sendable>(
        _ role: ForgeModelRole, _ prompt: ModelPrompt, as type: T.Type, budget: ModelBudget,
        image: ModelImage? = nil, repairs: Int = 2, check: (T) -> [String] = { _ in [] }
    ) async throws -> T {
        var current = prompt
        var refused: Swift.Set<String> = []
        var problems: [String] = []
        for round in 0...repairs {
            try Task.checkCancellation()
            let reply: ModelReply
            if role == .vision, let image {
                reply = try await model.look(current, image: image, budget)
            } else {
                reply = try await model.text(role, current, budget)
            }
            onReply(reply)
            let replyHash = ContentHash.sha256(reply.text)
            if refused.contains(replyHash) {
                log(current, reply, outcome: "repeat")
                break
            }
            switch Self.decode(type, from: reply.text) {
            case .success(let value):
                problems = check(value)
                if problems.isEmpty {
                    log(current, reply, outcome: "ok")
                    return value
                }
            case .failure(let reason):
                problems = [reason]
            }
            log(current, reply, outcome: "refused: " + problems.prefix(2).joined(separator: " "))
            refused.insert(replyHash)
            if round < repairs { current = Self.repair(prompt, problems: problems, round: round + 1) }
        }
        throw ForgeError.model(purpose: prompt.purpose, problems: problems)
    }

    /// The JSON object in a model's reply, decoded.
    public static func decode<T: Decodable>(_ type: T.Type, from text: String) -> Decoded<T> {
        guard let value = JSONValue.object(inModelText: text) ?? (try? JSONValue.parse(text)) else {
            return .failure("The answer was not one JSON object.")
        }
        do {
            let data = try value.data()
            return .success(try ForgeJSON.decoder.decode(type, from: data))
        } catch let error as DecodingError {
            return .failure(Self.describe(error))
        } catch {
            return .failure("The answer did not read: \(error.localizedDescription)")
        }
    }

    public enum Decoded<T> {
        case success(T)
        case failure(String)
    }

    static func repair(_ prompt: ModelPrompt, problems: [String], round: Int) -> ModelPrompt {
        let list = problems.prefix(8).map { "- " + $0 }.joined(separator: "\n")
        let user = prompt.user + "\n\nYour previous answer (try \(round)) had these problems:\n\(list)\n"
            + "Answer again with one JSON object of the same shape, fixed. Change nothing else."
        return ModelPrompt(purpose: prompt.purpose, system: prompt.system, user: user)
    }

    static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
            return keys.isEmpty ? "the answer" : keys.joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context):
            return "\(path(context)) is missing the key \"\(key.stringValue)\"."
        case .typeMismatch(let type, let context):
            return "\(path(context)) should be \(type)."
        case .valueNotFound(let type, let context):
            return "\(path(context)) should be a \(type), not null."
        case .dataCorrupted(let context):
            return "\(path(context)): \(context.debugDescription)"
        @unknown default:
            return "The answer did not read."
        }
    }

    private func log(_ prompt: ModelPrompt, _ reply: ModelReply, outcome: String) {
        guard let calls else { return }
        struct Line: Encodable {
            var at: Date; var purpose: String; var prompt: String; var promptTokens: Int; var completionTokens: Int
            var seconds: Double; var finish: String; var outcome: String
        }
        let line = Line(at: Date(), purpose: prompt.purpose, prompt: String(prompt.hash.prefix(16)), promptTokens: reply.promptTokens,
                        completionTokens: reply.completionTokens, seconds: reply.seconds, finish: reply.finish.rawValue,
                        outcome: outcome)
        if let data = try? ForgeJSON.line.encode(line), let text = String(data: data, encoding: .utf8) {
            try? AtomicFile.append(line: text, to: calls)
        }
    }
}
