import Foundation

/// A declaration a file's outline names: its line and its text.
public struct OutlineItem: Codable, Sendable, Equatable {
    public var line: Int
    public var text: String
}
