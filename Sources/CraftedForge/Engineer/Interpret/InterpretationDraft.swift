import Foundation

/// An interpretation as the coder writes it (the interpretation card of the plan's reference), before code checks it
/// and makes it the InterpretationCard the person chooses from.
public struct InterpretationDraft: Codable, Sendable, Equatable {
    public struct Port: Codable, Sendable, Equatable { public var path: String; public var lines: String?; public var how: String? }
    public struct Confidence: Codable, Sendable, Equatable { public var score: Double; public var basis: String? }
    public struct Effort: Codable, Sendable, Equatable {
        public var units: Int?; public var sourceLines: Int?; public var minutes: Int?; public var risk: String?; public var hardest: String?
    }

    public var name: String
    public var word: String
    public var summary: String
    public var commands: [InterpretationCard.Command]
    public var canvas: [String]
    public var handsOff: [String]
    public var accepts: [String]
    public var ports: [Port]
    public var leavesOut: [InterpretationCard.LeftOut]
    public var confidence: Confidence
    public var effort: Effort

    enum CodingKeys: String, CodingKey { case name, word, summary, commands, canvas, handsOff, accepts, ports, leavesOut, confidence, effort }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        name = try keyed.decode(String.self, forKey: .name)
        word = try keyed.decodeIfPresent(String.self, forKey: .word) ?? ""
        summary = try keyed.decode(String.self, forKey: .summary)
        commands = try keyed.decode([InterpretationCard.Command].self, forKey: .commands)
        canvas = try keyed.decodeIfPresent([String].self, forKey: .canvas) ?? []
        handsOff = try keyed.decodeIfPresent([String].self, forKey: .handsOff) ?? []
        accepts = try keyed.decodeIfPresent([String].self, forKey: .accepts) ?? []
        ports = try keyed.decodeIfPresent([Port].self, forKey: .ports) ?? []
        leavesOut = try keyed.decodeIfPresent([InterpretationCard.LeftOut].self, forKey: .leavesOut) ?? []
        confidence = try keyed.decodeIfPresent(Confidence.self, forKey: .confidence) ?? Confidence(score: 0.5, basis: nil)
        effort = try keyed.decodeIfPresent(Effort.self, forKey: .effort) ?? Effort()
    }

    /// The card the person chooses from.
    public func card(id: Int, archetype: InterpretationCard.Archetype) -> InterpretationCard {
        let lo = max(5, (effort.minutes ?? 20) * 3 / 4)
        let hi = max(lo + 5, (effort.minutes ?? 20) * 3 / 2)
        return InterpretationCard(id: id, archetype: archetype, name: name, word: word, summary: summary, commands: commands,
                                  canvas: canvas, handsOff: handsOff,
                                  ports: ports.map { InterpretationCard.Port(path: $0.path, how: $0.how ?? "port") },
                                  leavesOut: leavesOut, confidence: min(max(confidence.score, 0), 1), basis: confidence.basis ?? "",
                                  risk: effort.risk ?? "medium", minutes: [lo, hi])
    }
}
