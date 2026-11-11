import Foundation

/// A file the call wrote beside its hand-off: where, what kind, and what it is.
public struct HandoffFile: Codable, Sendable, Equatable {
    public var path: String
    public var kind: String
    public var what: String

    public init(path: String, kind: String, what: String) { self.path = path; self.kind = kind; self.what = what }
}
