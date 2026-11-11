import Foundation

/// Lines a model cites, read however it wrote them: "12-18", "12", "L12-L18", [12, 18], 12.
public struct LineRange: Codable, Sendable, Equatable, Hashable, CustomStringConvertible {
    public var start: Int
    public var end: Int

    public init(_ start: Int, _ end: Int) { self.start = start; self.end = max(start, end) }

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let number = try? single.decode(Int.self) {
            self.init(number, number)
        } else if let pair = try? single.decode([Int].self), let first = pair.first {
            self.init(first, pair.last ?? first)
        } else {
            let text = try single.decode(String.self)
            guard let range = LineRange.parse(text) else {
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "\"\(text)\" is not a line range like \"12-18\"")
            }
            self = range
        }
    }

    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        try single.encode(description)
    }

    public var description: String { start == end ? "\(start)" : "\(start)-\(end)" }

    /// "12-18", "L12-L18", "12–18", "12".
    public static func parse(_ text: String) -> LineRange? {
        let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let first = numbers.first else { return nil }
        return LineRange(first, numbers.count > 1 ? numbers[1] : first)
    }
}
