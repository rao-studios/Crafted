import Foundation

/// How the style speaks, for the host's model as it writes a piece: its tone, how its headlines read, words it uses
/// and words it avoids, and lines from the designer's own pieces.
public struct StyleVoice: Codable, Sendable, Equatable {
    public var tone: [String]
    public var headline: String?
    public var vocabulary: [String]
    public var avoid: [String]
    public var samples: [String]

    public init(tone: [String] = [], headline: String? = nil, vocabulary: [String] = [], avoid: [String] = [], samples: [String] = []) {
        self.tone = tone; self.headline = headline; self.vocabulary = vocabulary; self.avoid = avoid; self.samples = samples
    }

    enum CodingKeys: String, CodingKey { case tone, headline, vocabulary, avoid, samples }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tone = PieceLoose.list(c, .tone, of: String.self)
        headline = PieceLoose.string(c, .headline)?.nonEmptyText
        vocabulary = PieceLoose.list(c, .vocabulary, of: String.self)
        avoid = PieceLoose.list(c, .avoid, of: String.self)
        samples = PieceLoose.list(c, .samples, of: String.self)
    }
}
