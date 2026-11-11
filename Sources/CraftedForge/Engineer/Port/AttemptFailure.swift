import Foundation

/// Why a port attempt failed: the rung it fell from and what that rung said, trimmed and located, with a hint.
public struct AttemptFailure: Codable, Sendable, Equatable {
    /// scan, parse, build, test, answer
    public var rung: String
    /// One sentence each, the candidate's own lines first.
    public var lines: [String]
    public var hint: String?
    /// What identifies the failure apart from where it is: each diagnostic's file and message (Diagnostic.fingerprint),
    /// or the lines themselves when the rung said no diagnostics.
    public var keys: [String]

    public init(rung: String, lines: [String], hint: String? = nil, keys: [String]? = nil) {
        self.rung = rung; self.lines = lines; self.hint = hint; self.keys = keys ?? lines
    }

    /// The same failure whatever line it moved to.
    public var fingerprint: String { rung + "|" + keys.sorted().joined(separator: "|") }

    /// As a repair prompt says it.
    public var said: String {
        "It failed at \(rung):\n" + lines.map { "- " + $0 }.joined(separator: "\n") + (hint.map { "\nHint: \($0)" } ?? "")
    }
}
