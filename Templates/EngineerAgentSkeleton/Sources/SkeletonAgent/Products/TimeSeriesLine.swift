import Foundation

/// One line of a series: its id, its label, what it is (`observed`, `forecast`, `indicator`), and its points, oldest first.
public struct TimeSeriesLine: Codable, Sendable, Equatable {
    public var id: String
    public var label: String
    public var role: String
    public var points: [TimeSeriesPoint]

    public init(id: String, label: String, role: String = "observed", points: [TimeSeriesPoint]) {
        self.id = id; self.label = label; self.role = role; self.points = points
    }
}
