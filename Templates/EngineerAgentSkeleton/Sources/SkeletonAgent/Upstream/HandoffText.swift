import Foundation

/// A text handed on, in Markdown.
public struct HandoffText: Codable, Sendable, Equatable {
    public var name: String
    public var markdown: String

    public init(name: String, markdown: String) { self.name = name; self.markdown = markdown }
}
