//  WHAT: The store's regular expressions as Swift runs them: every match's capture groups (an unmatched group is
//        ""), and a whole-string test.
//  OUT:  The store validator's readers.

import Foundation

enum StoreRegex {
    /// The groups of every match of `pattern` in `text`, in order.
    static func groups(_ pattern: String, in text: String, options: NSRegularExpression.Options = []) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (1..<max(match.numberOfRanges, 1)).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }

    static func test(_ pattern: String, _ text: String, options: NSRegularExpression.Options = []) -> Bool {
        text.range(of: pattern, options: options.contains(.caseInsensitive) ? [.regularExpression, .caseInsensitive] : .regularExpression) != nil
    }

    /// `pattern` must match the whole of `text`.
    static func whole(_ pattern: String, _ text: String) -> Bool {
        test("^(?:" + pattern + ")$", text)
    }
}
