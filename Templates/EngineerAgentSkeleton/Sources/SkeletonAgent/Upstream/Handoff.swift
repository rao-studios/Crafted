//  WHAT: A hand-off between agents, `crafted-handoff/1`: what one call found, as facts, tables, texts and files, with
//        the calls that could come next. A package cannot call another; it hands on a file and a note, and the next
//        agent's call names that file in its `handoff` field.
//
//        {"format": "crafted-handoff/1", "from": {"word": "…", "command": "…", "at": "2026-11-10T12:00:00Z"},
//         "title": "…", "summary": "…", "facts": [{"name": "total", "value": 57.5, "unit": "USD"}],
//         "tables": [{"name": "…", "columns": […], "rows": [[…]]}], "text": [{"name": "…", "markdown": "…"}],
//         "files": [{"path": "…", "kind": "report", "what": "…"}], "asks": ["…"]}
//
//  PIN:  SMALL. A hand-off is at most 64 KB: a table that would not fit is cut, and says so in its own name.

import Foundation

public struct Handoff: Codable, Sendable, Equatable {
    public static let format = "crafted-handoff/1"
    public static let suffix = ".handoff.json"
    public static let limit = 64 * 1024

    public var format: String
    public var from: HandoffSource
    public var title: String
    public var summary: String
    public var facts: [Fact]
    public var tables: [HandoffTable]
    public var text: [HandoffText]
    public var files: [HandoffFile]
    public var asks: [String]

    public init(from: HandoffSource, title: String, summary: String, facts: [Fact] = [], tables: [HandoffTable] = [],
                text: [HandoffText] = [], files: [HandoffFile] = [], asks: [String] = []) {
        format = Self.format
        self.from = from; self.title = title; self.summary = summary; self.facts = facts; self.tables = tables
        self.text = text; self.files = files; self.asks = asks
    }

    /// The fact called `name`, from any agent upstream.
    public func fact(_ name: String) -> Fact? { facts.first { $0.name == name } }

    /// The table called `name`.
    public func table(_ name: String) -> HandoffTable? { tables.first { $0.name == name } }
}
