//  WHAT: Whether a value found by a secret pattern is one: how random it is (Shannon entropy per character), and
//        whether it is a placeholder, a hash, a path, a URL or an identifier that only looks like a key.
//  OUT:  SecretScan's pattern table.
//  PIN:  HASHES ARE NOT SECRETS. Pure hex (a git revision in Package.resolved, a sha256 in PROVENANCE.md) and UUIDs
//        never count as a high-entropy secret: the store requires Granite pinned to a 40-hex revision.

import Foundation

enum SecretValue {
    /// Bits per character of `text`'s own character distribution.
    static func entropy(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        var counts: [Character: Int] = [:]
        for character in text { counts[character, default: 0] += 1 }
        let total = Double(text.count)
        return counts.values.reduce(0) { sum, count in
            let p = Double(count) / total
            return sum - p * log2(p)
        }
    }

    static func hasDigit(_ text: String) -> Bool { text.contains { $0.isASCII && $0.isNumber } }
    static func hasLetter(_ text: String) -> Bool { text.contains { $0.isASCII && $0.isLetter } }

    /// Hex digits only, dashes aside: a hash, a revision, a UUID.
    static func isHex(_ text: String) -> Bool {
        let stripped = text.filter { $0 != "-" }
        return !stripped.isEmpty && stripped.allSatisfy(\.isHexDigit)
    }

    /// Words a person writes where a real value will go.
    static func isPlaceholder(_ value: String) -> Bool {
        let lowered = value.lowercased()
        if let first = value.first, "$<{%[(".contains(first) { return true }
        if Swift.Set(lowered).isSubset(of: ["x", "*", "-", "_", "."]) { return true }
        let words = ["your", "example", "placeholder", "changeme", "change_me", "xxxx", "dummy", "redacted", "process.env",
                     "environ", "getenv", "here", "insert", "replace", "todo", "sample"]
        return words.contains { lowered.contains($0) }
    }

    /// A value assigned to a key-like name that is plausibly the secret itself.
    static func isAssignedSecret(_ value: String) -> Bool {
        guard value.count >= 12, !isPlaceholder(value), hasLetter(value) else { return false }
        if value.contains("://") || value.hasPrefix("/") || value.hasPrefix("~") { return false }
        if value.hasSuffix(".swift") || value.hasSuffix(".json") || value.hasSuffix(".png") { return false }
        if isMadeOfWords(value) { return false }
        return hasDigit(value) || (value.count >= 20 && entropy(value) >= 4.0)
    }

    /// A run of 32+ key characters that reads as random: digits and letters, not hex, not a path, not a
    /// checksum or an inline picture, and spread over many characters.
    static func isRandomRun(_ value: String, _ match: NSTextCheckingResult, _ text: NSString) -> Bool {
        guard hasDigit(value), hasLetter(value), !isHex(value) else { return false }
        if value.range(of: "^sha(1|256|384|512)-", options: .regularExpression) != nil { return false }
        let slashParts = value.split(separator: "/")
        if slashParts.count >= 3, slashParts.allSatisfy({ $0.count >= 2 && $0.first!.isLetter }) { return false }
        let start = match.range.location
        let before = text.substring(with: NSRange(location: max(0, start - 24), length: min(24, start)))
        // Data said to be base64 (a data: URL, `Data(base64Encoded: "…")`) is a picture or a model, not a key.
        if before.hasSuffix("base64,") || before.hasSuffix("h1:") || before.range(of: #"base64Encoded:\s*"$"#, options: .regularExpression) != nil {
            return false
        }
        if isMadeOfWords(value) { return false }
        return entropy(value) >= 4.25
    }

    /// A name built of words: a slug of short parts (`Qwen3-Coder-Next-REAP-48B-A3B-mlx-4bit`) or a camel-case
    /// identifier (`testTheHolidaysOf2026AreTheExchanges`). Random keys split into parts of one or two characters.
    static func isMadeOfWords(_ value: String) -> Bool {
        let parts = value.split(whereSeparator: { $0 == "-" || $0 == "_" })
        if parts.count >= 3, Double(parts.reduce(0) { $0 + $1.count }) / Double(parts.count) < 10 { return true }
        let ns = value as NSString
        let tokens = wordToken.matches(in: value, range: NSRange(location: 0, length: ns.length))
        guard !tokens.isEmpty else { return false }
        return Double(tokens.reduce(0) { $0 + $1.range.length }) / Double(tokens.count) >= 3.5
    }

    static let wordToken = try! NSRegularExpression(pattern: "[A-Z]?[a-z]+|[A-Z]+(?![a-z])|[0-9]+")
}
