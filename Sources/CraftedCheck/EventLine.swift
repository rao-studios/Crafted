//  WHAT: One readable line for each forge event: stages, progress, models, findings, the three interpretations by
//        name, decisions with the default taken, units, gates, the listing, and how the run ended.
//  OUT:  crafted-check forge, which prints every event this way.

import CraftedCore
import CraftedForge
import Foundation

struct EventLine {
    private(set) var stages: [ForgeStage] = []

    mutating func text(_ event: ForgeEvent) -> String {
        switch event {
        case .stages(let all):
            stages = all
            return "[stages] " + all.map(\.title).joined(separator: " · ")
        case .stageStarted(let id):
            return "[stage] \(title(id))"
        case .stageFinished(let id, let summary):
            return "[done] \(title(id))" + (summary.isEmpty ? "" : ": \(summary)")
        case .progress(let progress):
            let percent = progress.fraction.map { " \(Int(($0 * 100).rounded()))%" } ?? ""
            let counts = progress.counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
            let rate = progress.tokensPerSecond.map { String(format: " · %.1f tok/s", $0) } ?? ""
            return "[progress] \(title(progress.stage))\(percent): \(progress.detail)" + (counts.isEmpty ? "" : " (\(counts))") + rate
        case .model(.loading(let role)):
            return "[model] loading the \(role.rawValue) model"
        case .model(.ready(let role, let seconds)):
            return String(format: "[model] the %@ model is ready (%.1f s)", role.rawValue, seconds)
        case .model(.released):
            return "[model] released"
        case .finding(let finding):
            return "[finding] \(finding.kind.rawValue): \(finding.text)"
        case .interpretations(let round, let cards):
            let names = cards.enumerated().map { "\($0.offset + 1). \($0.element.name) (\($0.element.archetype.rawValue), $\($0.element.word))" }
            return "[interpretations] round \(round): " + names.joined(separator: " · ")
        case .decision(let decision):
            return "[decision] \(decision.kind.rawValue): \(decision.question) → \(decision.defaultOption)"
        case .unit(let unit):
            let strategy = unit.strategy.map { " · \($0)" } ?? ""
            let detail = unit.detail.map { ": \($0)" } ?? ""
            return "[unit] \(unit.unit) \(unit.phase.rawValue) (attempt \(unit.attempt)\(strategy))\(detail)"
        case .gate(let gate):
            return Self.gate(gate)
        case .listing(let listing):
            return "[listing] \(listing.name) ($\(listing.word)) · \(listing.category.rawValue) · \(listing.license.rawValue)"
                + (listing.tagline.isEmpty ? "" : " · \(listing.tagline)")
        case .note(let text):
            return "[note] \(text)"
        case .completed(let report):
            var lines = ["[completed] \(report.identity.package) ($\(report.identity.word)) at \(report.package.path) · "
                         + "\(report.fileCount) files · built here: \(report.built ? "yes" : "no")"]
            lines += report.gates.map { "  " + Self.gate($0) }
            lines += report.verification.map { "  [verified] \($0)" }
            lines += report.leftOut.map { "  [left out] \($0)" }
            lines += report.notes.map { "  [note] \($0)" }
            return lines.joined(separator: "\n")
        case .failed(let failure):
            return "[failed] " + (failure.stage.map { "\(title($0)): " } ?? "") + failure.reason
        case .cancelled:
            return "[cancelled] the run stopped; it can be resumed"
        }
    }

    static func gate(_ gate: GateResult) -> String {
        let state = gate.skipped ? "skipped" : gate.passed ? "passed" : "FAILED"
        let detail = gate.detail.isEmpty ? "" : ": " + gate.detail.joined(separator: " | ")
        return "[gate] \(gate.name) \(state)\(detail)"
    }

    private func title(_ id: String) -> String {
        stages.first { $0.id == id }?.title ?? id
    }
}
