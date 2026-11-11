import Foundation

/// A table handed on: its columns, and its rows as text.
public struct HandoffTable: Codable, Sendable, Equatable {
    public var name: String
    public var columns: [String]
    public var rows: [[String]]

    public init(name: String, columns: [String], rows: [[String]]) { self.name = name; self.columns = columns; self.rows = rows }
}
