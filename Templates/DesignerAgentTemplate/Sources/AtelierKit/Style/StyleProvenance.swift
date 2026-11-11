import Foundation

/// Where the style came from: how many pieces were read and looked at, by which models, and every decision made on the
/// way (a colour darkened for contrast, a face that stands in for one that could not ship).
public struct StyleProvenance: Codable, Sendable, Equatable {
    public var pieces: Int
    public var looked: Int
    public var models: [String]
    public var decisions: [String]

    public init(pieces: Int = 0, looked: Int = 0, models: [String] = [], decisions: [String] = []) {
        self.pieces = pieces; self.looked = looked; self.models = models; self.decisions = decisions
    }

    enum CodingKeys: String, CodingKey { case pieces, looked, models, decisions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pieces = PieceLoose.int(c, .pieces) ?? 0
        looked = PieceLoose.int(c, .looked) ?? 0
        models = PieceLoose.list(c, .models, of: String.self)
        decisions = PieceLoose.list(c, .decisions, of: String.self)
    }
}
