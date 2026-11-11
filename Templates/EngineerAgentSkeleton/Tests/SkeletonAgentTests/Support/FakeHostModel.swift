import Foundation
import GraniteAgents

/// A host model that answers every object ask with one fixed JSON object, and counts the asks.
final class FakeHostModel: AgentHostModel, @unchecked Sendable {
    private let answer: Data
    private let lock = NSLock()
    private var count = 0

    init(answer: Data) { self.answer = answer }

    var asks: Int { lock.withLock { count } }

    func object(schema: Data, system: String, user: String, maxTokens: Int, seconds: Double) async throws -> Data {
        lock.withLock { count += 1 }
        return answer
    }

    func text(system: String, user: String, maxTokens: Int, seconds: Double) async throws -> String {
        lock.withLock { count += 1 }
        return String(decoding: answer, as: UTF8.self)
    }
}
