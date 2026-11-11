//  WHAT: What a finished assembly is: where the clean package is, its names, the gates it passed, how each command
//        was verified, and what was left out and why.
//  OUT:  The completed event, the listing page's facts, the README's "what was ported".

import CraftedCore
import Foundation

public struct PackageReport: Codable, Sendable, Equatable {
    /// The clean package folder: Generations/<id>/package/<Package>/.
    public var package: URL
    public var identity: AgentIdentity
    public var fileCount: Int
    public var gates: [GateResult]
    /// One line per command or format: "convert · source tests (11 of 11)".
    public var verification: [String]
    public var leftOut: [String]
    public var notes: [String]
    /// Whether `swift build` passed here; false when no toolchain ran.
    public var built: Bool

    public init(package: URL, identity: AgentIdentity, fileCount: Int, gates: [GateResult], verification: [String] = [],
                leftOut: [String] = [], notes: [String] = [], built: Bool) {
        self.package = package; self.identity = identity; self.fileCount = fileCount; self.gates = gates
        self.verification = verification; self.leftOut = leftOut; self.notes = notes; self.built = built
    }

    /// Every gate that ran passed.
    public var passed: Bool { gates.allSatisfy { $0.passed || $0.skipped } }
    public var failedGates: [GateResult] { gates.filter { !$0.passed && !$0.skipped } }
}
