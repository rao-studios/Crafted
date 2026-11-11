//  WHAT: What the looks agree on: per field, the value most pieces were seen with ("unsure" never counts), and per
//        colour role the letter most often named, split by the ground the piece stands on (a light piece's background
//        is the light theme's, a dark piece's the dark theme's).
//  OUT:  Reconcile (the observed rung of the trust order), the synthesis prompts (LOCKED facts).

import Foundation

public struct LookConsensus: Sendable, Equatable {
    public let looks: [Observation]
    /// Each look with the ground code measured for its piece.
    public let grounds: [String]

    public init(looks: [Observation], grounds: [String]) { self.looks = looks; self.grounds = grounds }

    /// The most common value, ties to the first seen; nil when every look was unsure.
    public static func vote(_ values: [String]) -> String? {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for value in values where value != "unsure" && !value.isEmpty {
            if counts[value] == nil { order.append(value) }
            counts[value, default: 0] += 1
        }
        return order.max { counts[$0]! < counts[$1]! || (counts[$0]! == counts[$1]! && order.firstIndex(of: $0)! > order.firstIndex(of: $1)!) }
    }

    public func vote(_ pick: (Observation) -> String) -> String? { Self.vote(looks.map(pick)) }
    public func votes(_ pick: (Observation) -> [String]) -> String? { Self.vote(looks.flatMap(pick)) }

    /// The letter most looks gave `role`, among pieces of `theme`'s ground.
    public func colour(_ role: String, theme: String) -> String? {
        let picked = zip(looks, grounds).filter { look, ground in
            theme == "dark" ? (ground == "dark" || look.ground == "dark") : (ground != "dark" && look.ground != "dark")
        }.map(\.0)
        return Self.vote(picked.flatMap { look -> [String] in
            switch role {
            case "background": return [look.colourRoles.background]
            case "ink": return [look.colourRoles.ink]
            case "accent": return Array(look.colourRoles.accent.prefix(1))
            case "secondary": return Array(look.colourRoles.secondary.prefix(1))
            case "inkMuted": return Array(look.colourRoles.muted.prefix(1))
            default: return []
            }
        })
    }

    /// The class most looks gave the type of `role`.
    public func typeClass(_ role: String) -> String? { Self.vote(looks.flatMap { $0.type.filter { $0.role == role }.map(\.class) }) }
    public func typeValue(_ role: String, _ pick: (Observation.TypeUse) -> String) -> String? {
        Self.vote(looks.flatMap { $0.type.filter { $0.role == role }.map(pick) })
    }
}
