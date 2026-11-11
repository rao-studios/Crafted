//  WHAT: One way an engineer's project could become an agent, as the person chooses between three: whole (the
//        product as one agent), core (its strongest capability done deeply), material (what it knows, for Canvas or
//        for other agents).
//  IN:   The engineer pipeline's interpret stage, checked against the verified use cases and the inventory.
//  OUT:  The Interpretations page; the chosen card drives the port plan.

import Foundation

public struct InterpretationCard: Codable, Sendable, Equatable, Identifiable {
    public enum Archetype: String, Codable, Sendable, CaseIterable { case whole, core, material }

    public struct Argument: Codable, Sendable, Equatable, Hashable {
        public var name: String
        /// string, integer, number, boolean, choice, path, [string], [number]
        public var type: String
        public var required: Bool
        public var note: String
        public var values: [String]?

        public init(name: String, type: String, required: Bool, note: String, values: [String]? = nil) {
            self.name = name; self.type = type; self.required = required; self.note = note; self.values = values
        }
    }

    public struct Product: Codable, Sendable, Equatable, Hashable {
        /// output, canvas, context
        public var channel: String
        /// text, json, csv, file, report, series, handoff
        public var kind: String
        public var what: String

        public init(channel: String, kind: String, what: String) {
            self.channel = channel; self.kind = kind; self.what = what
        }
    }

    public struct Command: Codable, Sendable, Equatable, Hashable {
        public var name: String
        public var summary: String
        public var args: [Argument]
        public var produces: [Product]
        public var usecases: [String]

        public init(name: String, summary: String, args: [Argument], produces: [Product], usecases: [String]) {
            self.name = name; self.summary = summary; self.args = args; self.produces = produces; self.usecases = usecases
        }
    }

    public struct Port: Codable, Sendable, Equatable, Hashable {
        public var path: String
        /// port, lift, carry
        public var how: String

        public init(path: String, how: String) { self.path = path; self.how = how }
    }

    public struct LeftOut: Codable, Sendable, Equatable, Hashable {
        public var what: String
        public var why: String

        public init(what: String, why: String) { self.what = what; self.why = why }
    }

    public var id: Int
    public var archetype: Archetype
    public var name: String
    public var word: String
    public var summary: String
    public var commands: [Command]
    public var canvas: [String]
    public var handsOff: [String]
    public var ports: [Port]
    public var leavesOut: [LeftOut]
    /// 0 to 1, and what it rests on.
    public var confidence: Double
    public var basis: String
    /// low, medium, high
    public var risk: String
    public var minutes: [Int]

    public init(id: Int, archetype: Archetype, name: String, word: String, summary: String, commands: [Command],
                canvas: [String] = [], handsOff: [String] = [], ports: [Port] = [], leavesOut: [LeftOut] = [],
                confidence: Double = 0.5, basis: String = "", risk: String = "medium", minutes: [Int] = []) {
        self.id = id; self.archetype = archetype; self.name = name; self.word = word; self.summary = summary
        self.commands = commands; self.canvas = canvas; self.handsOff = handsOff; self.ports = ports
        self.leavesOut = leavesOut; self.confidence = confidence; self.basis = basis; self.risk = risk; self.minutes = minutes
    }
}
