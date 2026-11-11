import Foundation

/// A day a reader draws a rule at, with its label.
public struct TimeSeriesMark: Codable, Sendable, Equatable {
    public var t: String
    public var label: String

    public init(t: String, label: String) { self.t = t; self.label = label }
}
