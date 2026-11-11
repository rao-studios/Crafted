import Foundation

/// One block of a report, in reading order.
public enum ReportBlock: Codable, Sendable, Equatable {
    case heading(String)
    case paragraph(String)
    /// Named values in a row of tiles.
    case facts([Fact])
    case table(columns: [String], rows: [[String]])
    case list([String])
    /// A horizontal bar per item, scaled to the largest.
    case bars(title: String, items: [ReportBar])
    /// A sentence set apart: a caveat, a source.
    case note(String)
    case divider
    case pageBreak
}
