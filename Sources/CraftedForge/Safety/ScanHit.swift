//  WHAT: One thing a content scan found: what it looks like and where (file and line). Never the value: a hit is
//        shown to the person, written to events.jsonl and put in a gate's detail, none of which may hold a secret.
//  OUT:  SecretScan and PrivacyScan answer these; the ship gate words them; the walk emits them as findings.

import Foundation

public struct ScanHit: Sendable, Equatable, Hashable {
    /// What it looks like, as a noun phrase: "an AWS access key", "a home-folder path".
    public var what: String
    public var path: String?
    /// 1-based.
    public var line: Int
    /// The kind of finding it becomes.
    public var kind: Finding.Kind
    /// Where it is in the scanned text (UTF-16), for redaction. Not shown.
    public var range: NSRange

    public init(what: String, path: String?, line: Int, kind: Finding.Kind, range: NSRange) {
        self.what = what; self.path = path; self.line = line; self.kind = kind; self.range = range
    }

    /// "Sources/App/Config.swift:12", or "line 12" when the text had no path.
    public var location: String { path.map { "\($0):\(line)" } ?? "line \(line)" }

    /// "Sources/App/Config.swift:12 holds what looks like an AWS access key."
    public var sentence: String { "\(location) holds what looks like \(what)." }

    public var finding: Finding { Finding(kind, sentence, path: path) }
}
