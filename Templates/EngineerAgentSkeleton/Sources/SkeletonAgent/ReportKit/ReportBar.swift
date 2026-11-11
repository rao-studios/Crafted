import Foundation

/// One bar of a report's bar block: a label and its value, with the value's text when it should read otherwise.
public struct ReportBar: Codable, Sendable, Equatable {
    public var label: String
    public var value: Double
    public var shown: String?

    public init(_ label: String, _ value: Double, shown: String? = nil) {
        self.label = label; self.value = value; self.shown = shown
    }
}
