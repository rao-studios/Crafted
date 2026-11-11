import Foundation

/// A `craft-timeseries/1` payload: lines of dated values a host recognizes by its file name (`<name>.timeseries.json`)
/// and its `schema`, and draws as an interactive chart. A forecast is said by the data: a line whose role is
/// `forecast`, or a point after `asOf`.
public struct TimeSeries: Codable, Sendable, Equatable {
    public static let schemaID = "craft-timeseries/1"
    public static let suffix = ".timeseries.json"

    /// Always `craft-timeseries/1`.
    public var schema: String
    public var title: String
    /// What a value is counted in: `USD`, `°C`.
    public var unit: String?
    /// How far apart the points are: `1d`.
    public var interval: String?
    /// The last observed day, `YYYY-MM-DD`.
    public var asOf: String?
    public var series: [TimeSeriesLine]
    public var marks: [TimeSeriesMark]?
    public var notes: [String]?

    public init(title: String, unit: String? = nil, interval: String? = nil, asOf: String? = nil, series: [TimeSeriesLine],
                marks: [TimeSeriesMark]? = nil, notes: [String]? = nil) {
        schema = Self.schemaID
        self.title = title; self.unit = unit; self.interval = interval; self.asOf = asOf; self.series = series
        self.marks = marks; self.notes = notes
    }
}
