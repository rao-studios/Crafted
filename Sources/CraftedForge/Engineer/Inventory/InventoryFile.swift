import Foundation

/// One file of the dropped project, with what the walk does with it. `sha256` and `lines` are of the redacted text,
/// and only for a file that is opened.
public struct InventoryFile: Codable, Sendable, Equatable {
    public var path: String
    public var verdict: FileVerdict
    public var language: SourceLanguage?
    public var bytes: Int
    public var lines: Int
    public var sha256: String?
    /// Secrets the content scan found and redacted, by line; never the value.
    public var redacted: [Int]

    public init(path: String, verdict: FileVerdict, language: SourceLanguage? = nil, bytes: Int = 0, lines: Int = 0,
                sha256: String? = nil, redacted: [Int] = []) {
        self.path = path; self.verdict = verdict; self.language = language; self.bytes = bytes; self.lines = lines
        self.sha256 = sha256; self.redacted = redacted
    }
}
