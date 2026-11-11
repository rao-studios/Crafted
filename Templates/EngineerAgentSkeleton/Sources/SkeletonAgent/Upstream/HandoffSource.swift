import Foundation

/// Which agent handed a file on, from which command, and when (ISO 8601).
public struct HandoffSource: Codable, Sendable, Equatable {
    public var word: String
    public var command: String
    public var at: String

    public init(word: String, command: String, at: String) { self.word = word; self.command = command; self.at = at }
}
