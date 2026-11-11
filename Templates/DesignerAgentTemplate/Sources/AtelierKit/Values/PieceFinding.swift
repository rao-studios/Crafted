import Foundation

/// One thing wrong with a piece, said so the model that wrote it can fix it: what kind of thing, which element, the
/// numbers that show it, and one sentence that says what to change. (After PlateAgent's PlateFinding.)
public struct PieceFinding: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        /// A text or a count past what a page holds.
        case limit
        /// Something a piece needs that it does not have: a headline, a stat's figure.
        case missing
        /// Words that do not fit their space even with the type fitted.
        case overflow
        /// Something past the page's edge.
        case outside
    }

    public var kind: Kind
    /// `page:1:block:3`, `page:1:zone:hero`, `pages`.
    public var element: String
    public var numbers: [Int]
    public var sentence: String

    public init(_ kind: Kind, _ element: String, numbers: [Int] = [], _ sentence: String) {
        self.kind = kind; self.element = element; self.numbers = numbers; self.sentence = sentence
    }
}
