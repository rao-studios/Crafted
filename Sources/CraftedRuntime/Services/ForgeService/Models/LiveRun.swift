import CraftedCore
import CraftedForge
import Foundation

/// Where a run stands, as the Workshop routes on it.
public enum ForgePhase: String, Equatable, Sendable {
    /// Reading the folder: inventory, measure, look, walk, cards, use cases.
    case analysing
    /// Engineer: three interpretations wait for the person.
    case choosing
    /// Writing and checking the package.
    case generating
    case done
    case failed
    /// Stopped by the person (or the app quit); Resume picks it up from its ledger.
    case cancelled

    /// The run's task is still going.
    public var isLive: Bool { self == .analysing || self == .choosing || self == .generating }
}

/// The run in flight (or the last one this launch), as the Generation page shows it: built from the run's events only.
public struct LiveRun: Equatable, Sendable {
    public var id: String
    public var role: CraftedRole
    public var phase: ForgePhase = .analysing
    public var stages: [ForgeStage] = []
    public var current: String?
    /// When the current stage started: how long the wash has crept through its band.
    public var stageStarted: Date?
    public var finished: Swift.Set<String> = []
    /// Each finished stage's one-line summary.
    public var summaries: [String: String] = [:]
    /// The latest snapshot; a later one replaces it.
    public var progress: ForgeProgress?
    public var tokensPerSecond: Double?
    public var model: ModelActivity?
    public var findings: [Finding] = []
    public var cards: [InterpretationCard] = []
    public var round = 0
    /// A question only the person can answer; the run waits on it.
    public var decision: Decision?
    /// Each unit of a port, at its latest step.
    public var units: [String: UnitEvent] = [:]
    public var gates: [GateResult] = []
    public var notes: [String] = []
    /// Bumped each time the forge's listing suggestion lands (the form reads the store again).
    public var listingRevision = 0
    public var report: PackageReport?
    public var failure: ForgeFailure?
    /// 0 to 1 over the stages' weights: what the painting washes in to.
    public var fraction: Double = 0
    public var started: Date
    public var ended: Date?
    /// Cancel was asked for; the run has not said `cancelled` yet.
    public var cancelling = false

    public init(id: String, role: CraftedRole, started: Date = Date()) {
        self.id = id
        self.role = role
        self.started = started
    }

    public var currentStage: ForgeStage? { stages.first { $0.id == current } }

    /// The stage's own fraction when the latest progress is about it.
    public var stageFraction: Double? {
        guard let progress, progress.stage == current else { return nil }
        return progress.fraction
    }

    public var elapsed: TimeInterval { (ended ?? Date()).timeIntervalSince(started) }
}

/// A download's result, kept per generation for the listing page.
public struct ExportOutcome: Equatable, Sendable {
    public var archive: String?
    public var report: PackageReport?
    public var failure: String?
    public var at: Date

    public init(archive: String?, report: PackageReport?, failure: String?, at: Date = Date()) {
        self.archive = archive; self.report = report; self.failure = failure; self.at = at
    }
}

/// What ForgeService's ticketed entries answer.
public enum ForgeReply: Sendable {
    /// The generation a run started (or resumed, or updated).
    case started(String)
    case exported(PackageReport, URL)
}

public enum ForgeServiceError: Error, LocalizedError, Equatable {
    case notConnected
    case busy
    case notLive(String)
    case badReply

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "The forge is not ready yet."
        case .busy: return "A generation is already running. One runs at a time, since one model fits in memory at a time."
        case .notLive(let id): return "Generation \(id) is not running."
        case .badReply: return "The forge answered something unexpected."
        }
    }
}
