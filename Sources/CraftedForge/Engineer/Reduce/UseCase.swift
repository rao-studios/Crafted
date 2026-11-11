//  WHAT: A use case: a trigger passes data through rules to an output, named by the author's intent, every link citing
//        its evidence ("path:12-20"). What it needs of the world decides whether it can be ported (Portability); a
//        second pass against only its cited lines decides whether it is verified (VerifyStage).
//  OUT:  Interpretations rest on verified use cases only; the plan cites them.

import Foundation

public struct UseCase: Codable, Sendable, Equatable {
    public struct Trigger: Codable, Sendable, Equatable { public var entry: String; public var evidence: String? }
    public struct Input: Codable, Sendable, Equatable { public var name: String; public var type: String?; public var source: String?; public var example: String? }
    public struct Step: Codable, Sendable, Equatable { public var text: String; public var evidence: String? }
    public struct Output: Codable, Sendable, Equatable { public var name: String; public var type: String?; public var form: String? }
    public struct Needs: Codable, Sendable, Equatable {
        public var pure = false, fileIO = false, ui = false, network = false, secret = false, hardware = false
        public var process = false, clock = false, random = false, state = false

        public init() {}

        enum CodingKeys: String, CodingKey { case pure, fileIO, ui, network, secret, hardware, process, clock, random, state }

        public init(from decoder: Decoder) throws {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            func flag(_ key: CodingKeys) -> Bool { (try? keyed.decodeIfPresent(Bool.self, forKey: key)) ?? false }
            pure = flag(.pure); fileIO = flag(.fileIO); ui = flag(.ui); network = flag(.network); secret = flag(.secret)
            hardware = flag(.hardware); process = flag(.process); clock = flag(.clock); random = flag(.random); state = flag(.state)
        }
    }
    public struct Portability: Codable, Sendable, Equatable {
        /// portable, portable-with-change, not-portable
        public var verdict: String
        public var change: [String]
        public var reasons: [String]
    }
    public struct Verifiability: Codable, Sendable, Equatable {
        public var sourceTests: [String]
        public var examples: [String]
        public var derivable: Bool

        enum CodingKeys: String, CodingKey { case sourceTests, examples, derivable }

        public init(sourceTests: [String] = [], examples: [String] = [], derivable: Bool = false) {
            self.sourceTests = sourceTests; self.examples = examples; self.derivable = derivable
        }

        public init(from decoder: Decoder) throws {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            sourceTests = (try? keyed.decodeIfPresent([String].self, forKey: .sourceTests)) ?? []
            examples = (try? keyed.decodeIfPresent([String].self, forKey: .examples)) ?? []
            derivable = (try? keyed.decodeIfPresent(Bool.self, forKey: .derivable)) ?? false
        }
    }

    public var id: String
    public var kind: String
    public var title: String
    public var actor: String
    public var trigger: Trigger
    public var inputs: [Input]
    public var steps: [Step]
    public var rules: [String]
    public var outputs: [Output]
    public var needs: Needs
    public var portability: Portability?
    public var verifiability: Verifiability
    public var value: Double
    public var confidence: Double
    public var verified: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, title, actor, trigger, inputs, steps, rules, outputs, needs, portability, verifiability, value, confidence, verified
    }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        id = try keyed.decode(String.self, forKey: .id)
        kind = try keyed.decodeIfPresent(String.self, forKey: .kind) ?? "business"
        title = try keyed.decode(String.self, forKey: .title)
        actor = try keyed.decodeIfPresent(String.self, forKey: .actor) ?? ""
        trigger = try keyed.decodeIfPresent(Trigger.self, forKey: .trigger) ?? Trigger(entry: "none (latent)", evidence: nil)
        inputs = try keyed.decodeIfPresent([Input].self, forKey: .inputs) ?? []
        steps = try keyed.decodeIfPresent([Step].self, forKey: .steps) ?? []
        rules = try keyed.decodeIfPresent([String].self, forKey: .rules) ?? []
        outputs = try keyed.decodeIfPresent([Output].self, forKey: .outputs) ?? []
        needs = try keyed.decodeIfPresent(Needs.self, forKey: .needs) ?? Needs()
        portability = try keyed.decodeIfPresent(Portability.self, forKey: .portability)
        verifiability = try keyed.decodeIfPresent(Verifiability.self, forKey: .verifiability) ?? Verifiability()
        value = try keyed.decodeIfPresent(Double.self, forKey: .value) ?? 0.5
        confidence = try keyed.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5
        verified = try keyed.decodeIfPresent(Bool.self, forKey: .verified) ?? false
    }

    /// Every citation the use case makes.
    public var evidence: [Evidence] {
        ([trigger.evidence] + steps.map(\.evidence)).compactMap { $0.flatMap(Evidence.parse) }
    }

    /// The use case in a few lines, for later prompts.
    public var digest: String {
        var text = "\(id) (\(kind)\(verified ? ", verified" : "")): \(title)"
        if !rules.isEmpty { text += "\n  rules: " + rules.joined(separator: "; ") }
        if !inputs.isEmpty { text += "\n  inputs: " + inputs.map { $0.name + ($0.type.map { ": \($0)" } ?? "") }.joined(separator: ", ") }
        if !outputs.isEmpty { text += "\n  outputs: " + outputs.map(\.name).joined(separator: ", ") }
        text += "\n  evidence: " + evidence.map(\.text).joined(separator: ", ")
        if let portability { text += "\n  portability: \(portability.verdict)" + (portability.change.isEmpty ? "" : " (\(portability.change.joined(separator: "; ")))") }
        return text
    }
}

