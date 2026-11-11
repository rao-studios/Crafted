import Foundation

/// A citation as a use case or a contract writes it: "path:12-18" (or "path" alone for the whole file).
public struct Evidence: Sendable, Equatable, Hashable {
    public var path: String
    public var range: LineRange?

    public init(path: String, range: LineRange?) { self.path = path; self.range = range }

    public static func parse(_ text: String) -> Evidence? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let colon = trimmed.lastIndex(of: ":"), let range = LineRange.parse(String(trimmed[trimmed.index(after: colon)...])) {
            return Evidence(path: String(trimmed[..<colon]), range: range)
        }
        return Evidence(path: trimmed, range: nil)
    }

    public var text: String { range.map { "\(path):\($0)" } ?? path }
}
