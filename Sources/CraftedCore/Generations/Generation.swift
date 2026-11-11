//  WHAT: One generation, as its tile and its pages show it: what was dropped, as which role, how far it got, the
//        agent it made, and when it was last downloaded. Kept as Generations/<id>/generation.json.
//  OUT:  The library grid, the forge (which writes its progress here), the listing page.

import Foundation

public enum GenerationStatus: String, Codable, Sendable, Equatable {
    /// A run is live: reading, generating, checking.
    case generating
    /// An engineer run is waiting for the person to pick one of three interpretations.
    case choosing
    /// A run is waiting for the person to answer a question (fonts, a parked unit, a licence).
    case waiting
    /// The run stopped before it finished (cancelled, quit, crashed); Resume picks it up from its ledger.
    case interrupted
    /// The package is made; the listing may still need the person.
    case finished
    case failed

    public var isLive: Bool { self == .generating || self == .choosing || self == .waiting }
}

public struct Generation: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var role: CraftedRole
    /// The folder the run reads, as a path.
    public var source: String
    public var created: Date
    public var updated: Date
    public var status: GenerationStatus
    /// The stage the run is in, by title, while it is live.
    public var stage: String?
    /// How far the run is, 0 to 1, by the stages' weights.
    public var fraction: Double?
    /// The agent's names as last assembled.
    public var identity: AgentIdentity?
    public var summary: String?
    /// The interpretation chosen, by title (engineer).
    public var interpretation: String?
    /// Whether the package was built here; nil until a build ran.
    public var built: Bool?
    public var failure: String?
    public var lastExport: Date?
    public var lastExportPath: String?

    public init(id: String, role: CraftedRole, source: String, created: Date = Date(), status: GenerationStatus = .generating) {
        self.id = id
        self.role = role
        self.source = source
        self.created = created
        self.updated = created
        self.status = status
    }

    public var sourceURL: URL { URL(fileURLWithPath: source, isDirectory: true) }
    public var sourceName: String { sourceURL.lastPathComponent }
    /// What the tile calls it: the agent's name once there is one, else the folder's.
    public var title: String { identity?.display ?? sourceName }
}
