import Foundation

/// A table as RFC 4180 CSV: a cell with a comma, a quote or a line break is quoted, its quotes doubled.
enum CSVText {
    static func text(columns: [String], rows: [[String]]) -> String {
        ([columns] + rows).map { $0.map(cell).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    static func cell(_ text: String) -> String {
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
