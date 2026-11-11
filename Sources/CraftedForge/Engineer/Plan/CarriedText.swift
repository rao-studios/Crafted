import Foundation

/// A file carried or lifted into the package, kept in the run with where it came from: the redacted text, as it ships.
public struct CarriedText: Codable, Sendable, Equatable {
    public var source: String
    public var text: String
}
