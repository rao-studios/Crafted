//  WHAT: The port loop's memory of what it has already tried, so it never spends an attempt twice: a prompt hash is
//        never sent again, a body hash is never compiled again (its first failure stands), and a diagnostic
//        fingerprint seen twice within one strategy ends that strategy.

import CraftedCore
import Foundation

public struct ThrashGuard: Codable, Sendable, Equatable {
    public private(set) var prompts: Swift.Set<String> = []
    /// Body hash → the failure it had.
    public private(set) var bodies: [String: AttemptFailure] = [:]
    /// Strategy → fingerprints of the failures it met.
    public private(set) var fingerprints: [String: [String]] = [:]

    public init() {}

    /// Whether `prompt` was never sent; marks it sent.
    public mutating func send(_ prompt: ModelPrompt) -> Bool { prompts.insert(prompt.hash).inserted }

    /// The failure an identical body already had.
    public func failure(of body: String) -> AttemptFailure? { bodies[Self.hash(body)] }

    public mutating func record(_ body: String, _ failure: AttemptFailure) { bodies[Self.hash(body)] = failure }

    /// Records `failure` under `strategy`; true when its fingerprint was already met there.
    public mutating func repeats(_ failure: AttemptFailure, in strategy: PortStrategy) -> Bool {
        let seen = fingerprints[strategy.rawValue] ?? []
        fingerprints[strategy.rawValue] = seen + [failure.fingerprint]
        return seen.contains(failure.fingerprint)
    }

    static func hash(_ body: String) -> String {
        ContentHash.sha256(body.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
