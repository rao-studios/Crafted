import Foundation

/// The coder's words for the listing: a name, a tagline, keywords and a category.
public struct WordSuggestion: Codable, Sendable, Equatable {
    public var name: String
    public var tagline: String
    public var keywords: [String]
    public var category: String
}
