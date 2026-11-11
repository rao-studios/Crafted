import Foundation

/// The coder's second look at one use case, against only the lines it cites.
public struct VerifyVerdict: Codable, Sendable, Equatable {
    public var id: String
    public var confirmed: Bool
    public var title: String?
    public var rules: [String]?
    public var notes: String?
}
