//  WHAT: What a call answers, as every host reads it (`granite-answer/1`): the files it wrote, what it made of what
//        the command promises, what it could only do in part, the series among its files, and the facts it found.
//  PIN:  COMPACT. The answer names files and says facts; a table, a report or a series lives in its file, never in
//        the answer, so a host's context stays small whatever the call wrote.

import Foundation
import GraniteAgents

public struct AgentResult: AgentAnswer, Equatable {
    /// The command that ran.
    public var command: String
    /// The first file written, or nil when the call wrote none.
    public var path: String?
    /// Every file written, absolute.
    public var paths: [String]
    /// Values the call found, each named, with its unit when it has one.
    public var facts: [Fact]
    /// One sentence each: what the call did, chose or could not do.
    public var notes: [String]
    public var made: [AgentMade]
    public var expected: [AgentExpected]
    public var problems: [AgentProblem]
    public var payloads: [AgentPayload]

    public init(command: String, path: String? = nil, paths: [String] = [], facts: [Fact] = [], notes: [String] = [],
                made: [AgentMade] = [], expected: [AgentExpected] = [], problems: [AgentProblem] = [], payloads: [AgentPayload] = []) {
        self.command = command; self.path = path; self.paths = paths; self.facts = facts; self.notes = notes
        self.made = made; self.expected = expected; self.problems = problems; self.payloads = payloads
    }

    /// The fact called `name`.
    public func fact(_ name: String) -> Fact? { facts.first { $0.name == name } }
}
