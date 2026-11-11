//  WHAT: What a run says as it goes: its stages up front, progress, the model it needs, what it found, the three
//        interpretations, a question, each unit of a port, each gate, and how it ended. The UI reads these; every
//        one is also a line of the run's events.jsonl.
//  OUT:  ForgeService (the app's state), crafted-check (the terminal), the run's log.

import CraftedCore
import Foundation

public enum ForgeEvent: Codable, Sendable, Equatable {
    /// Once, first: every stage the run will pass through, with its share of the painting.
    case stages([ForgeStage])
    case stageStarted(String)
    case stageFinished(String, summary: String)
    /// A snapshot; a later one replaces an earlier one.
    case progress(ForgeProgress)
    case model(ModelActivity)
    case finding(Finding)
    /// Engineer: three ways the project could become an agent. The run waits for a choice or a steer.
    case interpretations(round: Int, cards: [InterpretationCard])
    /// A question only the person can answer. The run waits.
    case decision(Decision)
    case unit(UnitEvent)
    case gate(GateResult)
    /// The listing the forge suggests; the store has merged it under the person's edits.
    case listing(AgentListing)
    case note(String)
    case completed(PackageReport)
    case failed(ForgeFailure)
    case cancelled
}

public enum ModelActivity: Codable, Sendable, Equatable {
    case loading(ForgeModelRole)
    case ready(ForgeModelRole, seconds: Double)
    case released
}

public struct ForgeStage: Codable, Sendable, Equatable, Identifiable, Hashable {
    public enum Part: String, Codable, Sendable { case analysis, generation }

    public var id: String
    public var title: String
    public var part: Part
    /// Its share of the whole run, and of the painting: weights are relative.
    public var weight: Double

    public init(id: String, title: String, part: Part, weight: Double) {
        self.id = id; self.title = title; self.part = part; self.weight = weight
    }

    /// How far a run is, 0 to 1: the stages before `current` whole, and `fraction` of the current one.
    public static func overall(_ stages: [ForgeStage], current: String?, fraction: Double?, finished: Swift.Set<String> = []) -> Double {
        let total = stages.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return 0 }
        var done = 0.0
        for stage in stages {
            if stage.id == current {
                done += stage.weight * min(max(fraction ?? 0, 0), 1)
                break
            }
            if finished.isEmpty || finished.contains(stage.id) { done += stage.weight }
        }
        return min(done / total, 1)
    }
}

public struct ForgeProgress: Codable, Sendable, Equatable {
    public var stage: String
    /// The line being read or written now: "Reading src/billing/tax.py (part 2 of 3)".
    public var detail: String
    /// Within the stage; nil when not known.
    public var fraction: Double?
    /// filesRead, filesTotal, useCases, units, unitsPassed, pieces, looked, …
    public var counts: [String: Int]
    public var tokensPerSecond: Double?

    public init(stage: String, detail: String, fraction: Double? = nil, counts: [String: Int] = [:], tokensPerSecond: Double? = nil) {
        self.stage = stage; self.detail = detail; self.fraction = fraction; self.counts = counts; self.tokensPerSecond = tokensPerSecond
    }
}

/// Something the run noticed that the person should know: a withheld file, a font that cannot ship, a fallback.
public struct Finding: Codable, Sendable, Equatable, Hashable {
    public enum Kind: String, Codable, Sendable { case withheld, skipped, rights, licence, fallback, secret, info }

    public var kind: Kind
    public var text: String
    public var path: String?

    public init(_ kind: Kind, _ text: String, path: String? = nil) {
        self.kind = kind; self.text = text; self.path = path
    }
}

/// One unit of a port, as it climbs the ladder.
public struct UnitEvent: Codable, Sendable, Equatable {
    public enum Phase: String, Codable, Sendable { case started, attempt, built, tested, passed, parked, dropped }

    public var unit: String
    public var phase: Phase
    public var attempt: Int
    public var strategy: String?
    public var detail: String?

    public init(unit: String, phase: Phase, attempt: Int = 0, strategy: String? = nil, detail: String? = nil) {
        self.unit = unit; self.phase = phase; self.attempt = attempt; self.strategy = strategy; self.detail = detail
    }
}

public struct GateResult: Codable, Sendable, Equatable, Hashable {
    public var name: String
    public var passed: Bool
    /// One sentence each: what failed and where, or what was checked.
    public var detail: [String]
    /// A gate that could not run here (no toolchain) is skipped, not failed.
    public var skipped: Bool

    public init(name: String, passed: Bool, detail: [String] = [], skipped: Bool = false) {
        self.name = name; self.passed = passed; self.detail = detail; self.skipped = skipped
    }
}

public struct ForgeFailure: Codable, Sendable, Equatable {
    public var reason: String
    public var stage: String?
    /// Resume picks up from the ledger.
    public var resumable: Bool

    public init(reason: String, stage: String? = nil, resumable: Bool = true) {
        self.reason = reason; self.stage = stage; self.resumable = resumable
    }
}
