//  WHAT: How a run is asked to go: who to credit, whether to build and install, how many pictures to look at, how
//        long a unit may be tried, and (headless) which answers to give without asking.

import Foundation

public struct ForgeOptions: Codable, Sendable, Equatable {
    /// The designer's name, from Settings.
    public var credit: String?
    public var creditURL: String?
    /// Answer every question with its default (crafted-check, tests).
    public var autoDecide: Bool
    /// Pick this interpretation without asking (crafted-check, tests). Zero-based.
    public var autoChoose: Int?
    /// How many pieces the vision model looks at, 8 to 48.
    public var looks: Int
    /// Generations a port unit may take before it is parked.
    public var unitAttempts: Int
    /// Build the package with the toolchain when there is one.
    public var build: Bool
    /// Install it on a scratch shelf and call each command over the wire.
    public var install: Bool

    public init(credit: String? = nil, creditURL: String? = nil, autoDecide: Bool = false, autoChoose: Int? = nil,
                looks: Int = 24, unitAttempts: Int = 20, build: Bool = true, install: Bool = true) {
        self.credit = credit; self.creditURL = creditURL; self.autoDecide = autoDecide; self.autoChoose = autoChoose
        self.looks = looks; self.unitAttempts = unitAttempts; self.build = build; self.install = install
    }
}
