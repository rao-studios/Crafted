//  WHAT: One file of the project, as the coder read it: its role and summary, what it declares, the operations it
//        defines, the rules it decides or computes, what it reads and writes, what touches the world, and the use
//        cases it serves, each citing its lines. Code fills path, sha256, language and lines, and strikes what the
//        lines do not show (CardGrounding).
//  OUT:  The reduce stage (domain, use cases), the interpretations' evidence, the plan.

import Foundation

public struct FileCard: Codable, Sendable, Equatable {
    public struct Entity: Codable, Sendable, Equatable { public var name: String; public var kind: String?; public var lines: LineRange }
    public struct Operation: Codable, Sendable, Equatable {
        public var name: String; public var signature: String?; public var lines: LineRange; public var does: String?; public var purity: String?
    }
    public struct Rule: Codable, Sendable, Equatable { public var statement: String; public var formula: String?; public var lines: LineRange }
    public struct Effect: Codable, Sendable, Equatable { public var kind: String; public var detail: String?; public var lines: LineRange? }
    public struct Spotted: Codable, Sendable, Equatable { public var title: String; public var entry: String? }

    public var path: String
    public var sha256: String
    public var language: String
    public var lines: Int
    public var role: String
    public var summary: String
    public var entities: [Entity]
    public var operations: [Operation]
    public var rules: [Rule]
    public var inputs: [String]
    public var outputs: [String]
    public var effects: [Effect]
    public var depends: [String]
    public var spotted: [Spotted]
    public var importance: Double
    public var why: String
    /// What code struck as ungrounded, one sentence each.
    public var struck: [String]

    enum CodingKeys: String, CodingKey {
        case path, sha256, language, lines, role, summary, entities, operations, rules, inputs, outputs, effects, depends, spotted, importance, why, struck
    }

    public init(path: String, sha256: String, language: String, lines: Int, role: String, summary: String, entities: [Entity] = [],
                operations: [Operation] = [], rules: [Rule] = [], inputs: [String] = [], outputs: [String] = [], effects: [Effect] = [],
                depends: [String] = [], spotted: [Spotted] = [], importance: Double = 0.5, why: String = "", struck: [String] = []) {
        self.path = path; self.sha256 = sha256; self.language = language; self.lines = lines; self.role = role; self.summary = summary
        self.entities = entities; self.operations = operations; self.rules = rules; self.inputs = inputs; self.outputs = outputs
        self.effects = effects; self.depends = depends; self.spotted = spotted; self.importance = importance; self.why = why; self.struck = struck
    }

    /// A model's card: code's fields may be missing, every list may be.
    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        path = try keyed.decodeIfPresent(String.self, forKey: .path) ?? ""
        sha256 = try keyed.decodeIfPresent(String.self, forKey: .sha256) ?? ""
        language = try keyed.decodeIfPresent(String.self, forKey: .language) ?? ""
        lines = try keyed.decodeIfPresent(Int.self, forKey: .lines) ?? 0
        role = try keyed.decodeIfPresent(String.self, forKey: .role) ?? "logic"
        summary = try keyed.decode(String.self, forKey: .summary)
        entities = try keyed.decodeIfPresent([Entity].self, forKey: .entities) ?? []
        operations = try keyed.decodeIfPresent([Operation].self, forKey: .operations) ?? []
        rules = try keyed.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        inputs = try keyed.decodeIfPresent([String].self, forKey: .inputs) ?? []
        outputs = try keyed.decodeIfPresent([String].self, forKey: .outputs) ?? []
        effects = try keyed.decodeIfPresent([Effect].self, forKey: .effects) ?? []
        depends = try keyed.decodeIfPresent([String].self, forKey: .depends) ?? []
        spotted = try keyed.decodeIfPresent([Spotted].self, forKey: .spotted) ?? []
        importance = try keyed.decodeIfPresent(Double.self, forKey: .importance) ?? 0.5
        why = try keyed.decodeIfPresent(String.self, forKey: .why) ?? ""
        struck = try keyed.decodeIfPresent([String].self, forKey: .struck) ?? []
    }

    /// The card in a few lines, for later prompts.
    public var digest: String {
        var lines = ["\(path) (\(role)): \(summary)"]
        if !operations.isEmpty { lines.append("  operations: " + operations.map { "\($0.signature ?? $0.name) [\($0.lines)]" }.joined(separator: "; ")) }
        if !rules.isEmpty { lines.append("  rules: " + rules.map { "\($0.statement)" + ($0.formula.map { " (\($0))" } ?? "") + " [\($0.lines)]" }.joined(separator: "; ")) }
        if !entities.isEmpty { lines.append("  entities: " + entities.map { "\($0.name) [\($0.lines)]" }.joined(separator: "; ")) }
        if !effects.isEmpty { lines.append("  effects: " + effects.map { $0.kind + ($0.detail.map { " (\($0))" } ?? "") }.joined(separator: "; ")) }
        return lines.joined(separator: "\n")
    }
}
