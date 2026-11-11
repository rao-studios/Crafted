//  WHAT: Finds secrets in text and redacts them: provider key shapes (AWS, GitHub, Slack, Stripe, Google, OpenAI,
//        Anthropic, Hugging Face, npm, SendGrid), private-key blocks, JSON Web Tokens, credentials in connection
//        strings, long values assigned to key-like names, and high-entropy runs of 32 or more characters.
//  IN:   Any text: a source file before it enters a prompt, a file as it is written, a shipped file.
//  OUT:  The walk (findings, and `redact` before a prompt), the pipelines as they write, the ship gate.
//  PIN:  FINDINGS NAME FILE AND LINE, NEVER THE VALUE. A finding goes to the person, the log and the gate's detail.
//  PIN:  ONE MATCH PER SPAN. Patterns run most specific first; a later pattern never claims a span an earlier one
//        took, so a GitHub token inside `token = "…"` is one finding, a GitHub token.

import Foundation

public enum SecretScan {
    public static let placeholder = "[REDACTED]"

    /// Each secret in `text`, as a finding naming `path` and the line. Never the value.
    public static func findings(in text: String, path: String?) -> [Finding] {
        var seen: Swift.Set<String> = []
        return hits(in: text, path: path).compactMap { hit in
            seen.insert(hit.sentence).inserted ? hit.finding : nil
        }
    }

    /// Each secret in `text`, in order, with its span.
    public static func hits(in text: String, path: String? = nil) -> [ScanHit] {
        let ns = text as NSString
        guard ns.length > 0 else { return [] }
        let full = NSRange(location: 0, length: ns.length)
        let lines = LineIndex(ns)
        var taken: [NSRange] = []
        var hits: [ScanHit] = []
        for pattern in patterns {
            for match in pattern.regex.matches(in: text, range: full) {
                let range = match.range(at: pattern.group)
                guard range.location != NSNotFound, range.length > 0 else { continue }
                let value = ns.substring(with: range)
                guard pattern.accept(value, match, ns) else { continue }
                guard !taken.contains(where: { NSIntersectionRange($0, range).length > 0 }) else { continue }
                taken.append(range)
                hits.append(ScanHit(what: pattern.describe(match, ns), path: path, line: lines.line(at: range.location),
                                    kind: .secret, range: range))
            }
        }
        return hits.sorted { $0.range.location < $1.range.location }
    }

    /// Whether `text` holds anything that looks like a secret.
    public static func containsSecret(_ text: String) -> Bool { !hits(in: text).isEmpty }

    /// `text` with every secret replaced by `[REDACTED]`; the rest is untouched.
    public static func redact(_ text: String) -> String {
        replace(hits(in: text), in: text)
    }

    /// `text` with each hit's span replaced by `[REDACTED]`.
    static func replace(_ hits: [ScanHit], in text: String) -> String {
        guard !hits.isEmpty else { return text }
        let out = NSMutableString(string: text)
        for hit in hits.sorted(by: { $0.range.location > $1.range.location }) {
            out.replaceCharacters(in: hit.range, with: placeholder)
        }
        return out as String
    }
}

/// Line numbers by UTF-16 offset, for a text scanned once.
struct LineIndex {
    private var starts: [Int] = [0]

    init(_ text: NSString) {
        let newline = unichar(10)
        for offset in 0..<text.length where text.character(at: offset) == newline {
            starts.append(offset + 1)
        }
    }

    /// The 1-based line holding `offset`.
    func line(at offset: Int) -> Int {
        var low = 0
        var high = starts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if starts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low + 1
    }
}
