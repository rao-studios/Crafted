import Foundation

/// One dated value, with a band for a forecast. `t` is `YYYY-MM-DD` or an ISO 8601 date and time.
public struct TimeSeriesPoint: Codable, Sendable, Equatable {
    public var t: String
    public var v: Double
    public var lo: Double?
    public var hi: Double?

    public init(t: String, v: Double, lo: Double? = nil, hi: Double? = nil) {
        self.t = t; self.v = v; self.lo = lo; self.hi = hi
    }
}
