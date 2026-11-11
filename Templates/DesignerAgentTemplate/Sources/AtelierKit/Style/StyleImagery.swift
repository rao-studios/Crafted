import Foundation

/// A style's imagery: what kinds of picture it uses and how it treats them, its rules, and what stands in for a
/// picture the call did not give (`placeholder`: solid, gradient, duotone, pattern).
public struct StyleImagery: Codable, Sendable, Equatable {
    public var kinds: [String]
    public var treatments: [String]
    public var rules: [String]
    public var placeholder: String

    public init(kinds: [String] = [], treatments: [String] = [], rules: [String] = [], placeholder: String = "solid") {
        self.kinds = kinds; self.treatments = treatments; self.rules = rules; self.placeholder = placeholder
    }

    enum CodingKeys: String, CodingKey { case kinds, treatments, rules, placeholder }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kinds = PieceLoose.list(c, .kinds, of: String.self)
        treatments = PieceLoose.list(c, .treatments, of: String.self)
        rules = PieceLoose.list(c, .rules, of: String.self)
        placeholder = PieceLoose.string(c, .placeholder) ?? "solid"
    }
}
