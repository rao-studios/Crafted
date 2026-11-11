//  WHAT: Where a port stands, kept in the run after every step: the identity its work tree is named with, which units
//        and handlers are ported, how each got there, which commands were dropped and why, and how each command is
//        verified. A resumed run starts from it; the README and PROVENANCE say it.
//  OUT:  port.json.

import CraftedCore
import Foundation

public struct PortState: Codable, Sendable, Equatable {
    public struct Record: Codable, Sendable, Equatable {
        /// passed, parked, dropped
        public var status: String
        public var attempts: Int
        public var strategy: String?
        public var sourceVectors: Int
        public var derivedVectors: Int
        public var heldOut: Int

        public init(status: String, attempts: Int, strategy: String? = nil, sourceVectors: Int = 0, derivedVectors: Int = 0, heldOut: Int = 0) {
            self.status = status; self.attempts = attempts; self.strategy = strategy
            self.sourceVectors = sourceVectors; self.derivedVectors = derivedVectors; self.heldOut = heldOut
        }
    }

    public struct Dropped: Codable, Sendable, Equatable {
        public var command: String
        public var why: String
    }

    public var identity: AgentIdentity
    /// Units, and handlers by `SkeletonCodegen.handlerKey`.
    public var ported: [String]
    public var records: [String: Record]
    public var dropped: [Dropped]
    /// Whether the tree built with every body a stub.
    public var green: Bool

    public init(identity: AgentIdentity, ported: [String] = [], records: [String: Record] = [:], dropped: [Dropped] = [], green: Bool = false) {
        self.identity = identity; self.ported = ported; self.records = records; self.dropped = dropped; self.green = green
    }

    public var droppedNames: Swift.Set<String> { Swift.Set(dropped.map(\.command)) }

    /// "convert · ported from source tests (6 vectors) and derived (4, 3 held out), its canonical call answered".
    public func verification(_ spec: PortSpec) -> [String] {
        spec.commands.filter { !droppedNames.contains($0.name) }.map { command in
            let units = command.uses.compactMap { name in records[name].map { (name, $0) } }
            let source = units.reduce(0) { $0 + $1.1.sourceVectors }
            let derived = units.reduce(0) { $0 + $1.1.derivedVectors }
            let held = units.reduce(0) { $0 + $1.1.heldOut }
            let handler = records[SkeletonCodegen.handlerKey(command.name)]
            var parts: [String] = []
            if source > 0 { parts.append("\(source) vectors from the source's tests") }
            if derived > 0 { parts.append("\(derived) derived vectors") }
            if held > 0 { parts.append("\(held) of the \(source + derived) held out of the port's prompt") }
            if units.isEmpty { parts.append("no logic of its own") }
            parts.append(handler?.status == "passed" ? "its canonical call answers" : "its canonical call is not checked")
            let level = source > 0 ? "source tests" : (derived > 0 ? "derived vectors" : "call only")
            return "\(command.name) · \(level): " + parts.joined(separator: ", ")
        }
    }
}
