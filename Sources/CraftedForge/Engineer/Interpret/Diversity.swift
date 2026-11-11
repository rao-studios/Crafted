//  WHAT: How much two interpretations overlap: the share of what they offer that they offer alike, measured over their
//        commands (by name and by the use cases they rest on). Over 60% and the later one is asked again.

import Foundation

public enum Diversity {
    public static let limit = 0.6

    /// What a card offers, as a set: each command's name and each use case a command rests on.
    static func offer(_ commands: [InterpretationCard.Command]) -> Swift.Set<String> {
        Swift.Set(commands.map { "command:" + $0.name.lowercased() } + commands.flatMap { $0.usecases.map { "usecase:" + $0 } })
    }

    /// Jaccard overlap of two cards' offers, 0 to 1.
    public static func overlap(_ a: [InterpretationCard.Command], _ b: [InterpretationCard.Command]) -> Double {
        let left = offer(a), right = offer(b)
        let union = left.union(right)
        guard !union.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(union.count)
    }

    /// The first earlier card `commands` overlaps by more than the limit, by index.
    public static func clash(_ commands: [InterpretationCard.Command], with earlier: [[InterpretationCard.Command]]) -> Int? {
        earlier.firstIndex { overlap(commands, $0) > limit }
    }
}
