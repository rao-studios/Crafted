//  WHAT: Every file of the dropped project with its verdict, and the redacted text of each file that is opened. What
//        every later stage reads instead of the folder, so a secret never leaves this stage unredacted.
//  PIN:  REDACTED BEFORE ANY PROMPT. `text(_:)` answers only the redacted text; the raw bytes are read once, scanned,
//        and dropped. A file with a secret-shaped name is never opened.

import Foundation

public struct Inventory: Codable, Sendable, Equatable {
    public var files: [InventoryFile]
    /// Redacted text of every opened file, by path.
    public var texts: [String: String]
    /// The source project's licence, when its LICENSE file says one plainly.
    public var licence: String?

    public init(files: [InventoryFile], texts: [String: String] = [:], licence: String? = nil) {
        self.files = files; self.texts = texts; self.licence = licence
    }

    public func file(_ path: String) -> InventoryFile? { files.first { $0.path == path } }

    /// The redacted text of an opened file.
    public func text(_ path: String) -> String? { texts[path] }

    /// The redacted lines of an opened file.
    public func lines(_ path: String) -> [String] {
        guard let text = texts[path] else { return [] }
        return SourceText.lines(text)
    }

    public func with(_ verdict: FileVerdict) -> [InventoryFile] { files.filter { $0.verdict == verdict } }

    /// Counts by verdict, for the stage's summary.
    public var counts: [String: Int] {
        Dictionary(grouping: files, by: { $0.verdict.rawValue }).mapValues(\.count)
    }
}
