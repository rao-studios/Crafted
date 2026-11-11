import Foundation

/// What the gates found, kept for assembly: how each format was verified, what was left out of the package and why,
/// and notes for the person. artefacts/report.json.
public struct DesignerReport: Codable, Sendable, Equatable {
    public var verification: [String]
    public var leftOut: [String]
    public var notes: [String]
    /// Whether the proof was drawn by the built agent, so the README may show it.
    public var proof: Bool

    public init(verification: [String] = [], leftOut: [String] = [], notes: [String] = [], proof: Bool = false) {
        self.verification = verification; self.leftOut = leftOut; self.notes = notes; self.proof = proof
    }
}
