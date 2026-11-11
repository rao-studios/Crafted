//  WHAT: A file's text as the walk shows it to a model and checks a model against it: its lines, a numbered listing,
//        the lines a range cites cut verbatim, and chunks at declaration boundaries for a file too long for one ask.

import Foundation

public enum SourceText {
    /// Lines without their terminators; a final newline does not make an empty last line.
    public static func lines(_ text: String) -> [String] {
        var lines = text.components(separatedBy: "\n").map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        if lines.last == "" { lines.removeLast() }
        return lines
    }

    /// `lines[from...through]` numbered as the file numbers them ("  12| text").
    public static func numbered(_ lines: [String], from: Int = 1, through: Int? = nil) -> String {
        let last = min(through ?? lines.count, lines.count)
        guard from >= 1, from <= last else { return "" }
        let width = String(last).count
        return (from...last).map { number in
            let label = String(number)
            return String(repeating: " ", count: width - label.count) + label + "| " + lines[number - 1]
        }.joined(separator: "\n")
    }

    /// The text of `range` in `lines`, or nil when the range is not in the file.
    public static func cut(_ lines: [String], _ range: LineRange) -> String? {
        guard range.start >= 1, range.end >= range.start, range.end <= lines.count else { return nil }
        return lines[(range.start - 1)...(range.end - 1)].joined(separator: "\n")
    }

    /// Chunks of at most `limit` lines, each ending before a declaration the outline names when one is near.
    public static func chunks(_ lines: [String], outline: [OutlineItem], limit: Int = 260) -> [ClosedRange<Int>] {
        guard lines.count > limit else { return lines.isEmpty ? [] : [1...lines.count] }
        let starts = outline.map(\.line).filter { $0 > 1 }.sorted()
        var ranges: [ClosedRange<Int>] = []
        var start = 1
        while start <= lines.count {
            var end = min(start + limit - 1, lines.count)
            if end < lines.count, let cut = starts.last(where: { $0 > start + limit / 3 && $0 <= end + 1 }) { end = cut - 1 }
            ranges.append(start...end)
            start = end + 1
        }
        return ranges
    }
}
