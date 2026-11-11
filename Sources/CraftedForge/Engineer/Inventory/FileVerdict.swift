import Foundation

/// What the walk does with a file, said for every file so nothing is dropped silently.
public enum FileVerdict: String, Codable, Sendable, CaseIterable {
    /// Source code: carded and offered to the port.
    case read
    /// Data the code reads (a table, a template, a sample): may be carried as it is.
    case resource
    /// The source's tests: read for vectors.
    case test
    /// A manifest: read for the brief.
    case manifest
    /// A README or other document: read for the brief and the intent.
    case doc
    /// A secret-shaped name: never opened.
    case withheld = "withheld: secret-name"
    case generated = "skipped: generated"
    case vendored = "skipped: vendored"
    case lockfile = "skipped: lockfile"
    case media = "skipped: media"
    case binary = "skipped: binary"
    case large = "skipped: too large"
    case hidden = "skipped: hidden"
    case unknown = "skipped: not code or data"

    /// Whether the walk opens the file at all.
    public var isOpened: Bool { [.read, .resource, .test, .manifest, .doc].contains(self) }
}
