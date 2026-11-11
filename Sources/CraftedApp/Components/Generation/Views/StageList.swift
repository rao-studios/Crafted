import CraftedCore
import CraftedForge
import CraftedRuntime
import SwiftUI

/// Every stage the run passes through, in order: done, here, to come, with each finished stage's one line.
struct StageList: View {
    let run: LiveRun

    var body: some View {
        VStack(alignment: .leading, spacing: .layer2) {
            SectionLabel(run.role == .designer ? "Reading your designs" : "Reading your project")
            ForEach(run.stages) { stage in
                let state = stageState(stage)
                HStack(alignment: .firstTextBaseline, spacing: .layer2) {
                    Image(systemName: symbol(state))
                        .font(.craftGlyph(.caption, weight: .semibold))
                        .foregroundStyle(tint(state))
                        .frame(width: CraftInset.iconGutter)
                    VStack(alignment: .leading, spacing: .hairline) {
                        Text(stage.title).craftType(state == .now ? .labelStrong : .label)
                            .foregroundStyle(state == .later ? Color.craftInkDim : Color.craftInk)
                        if let summary = run.summaries[stage.id], state == .done {
                            Text(summary).craftType(.caption).foregroundStyle(Color.craftInkDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if state == .now, let fraction = run.stageFraction {
                            CraftMeter(fraction: fraction).frame(maxWidth: 160)
                        }
                    }
                }
            }
        }
    }

    enum StageState { case done, now, later }

    private func stageState(_ stage: ForgeStage) -> StageState {
        if run.finished.contains(stage.id) || run.phase == .done { return .done }
        if stage.id == run.current { return .now }
        return .later
    }

    private func symbol(_ state: StageState) -> String {
        switch state {
        case .done: return "checkmark.circle.fill"
        case .now: return run.phase.isLive ? "circle.dotted" : "pause.circle"
        case .later: return "circle"
        }
    }

    private func tint(_ state: StageState) -> Color {
        switch state {
        case .done: return .craftSuccess
        case .now: return .craftTint
        case .later: return .craftInkFaint
        }
    }
}

/// The line being read or written now, the counts, elapsed time, the model and its rate.
struct RunFacts: View {
    let run: LiveRun

    var body: some View {
        VStack(alignment: .leading, spacing: .layer3) {
            if let detail = run.progress?.detail, !detail.isEmpty, run.phase.isLive {
                Text(detail).craftType(.codeSmall).foregroundStyle(Color.craftInkSoft)
                    .lineLimit(3).truncationMode(.middle).textSelection(.enabled)
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                FlowLayout(spacing: .layer5, lineSpacing: .layer3) {
                    CraftStat(value: "\(Int((run.fraction * 100).rounded()))%", label: "Done")
                    CraftStat(value: CraftFormat.duration(run.elapsed), label: "Elapsed")
                    ForEach(counts, id: \.0) { count in CraftStat(value: count.1, label: count.0) }
                    if let rate = run.tokensPerSecond { CraftStat(value: String(format: "%.1f", rate), label: "Tokens/s") }
                }
            }
            if let model = modelLine {
                HStack(spacing: .layer2) {
                    Image(systemName: "cpu").font(.craftGlyph(.caption)).foregroundStyle(Color.craftInkDim)
                    Text(model).craftType(.caption).foregroundStyle(Color.craftInkDim)
                }
            }
            if !run.findings.isEmpty {
                VStack(alignment: .leading, spacing: .layer1) {
                    SectionLabel("Noticed")
                    ForEach(Array(run.findings.suffix(6).enumerated()), id: \.offset) { _, finding in
                        Text("· " + finding.text).craftType(.caption).foregroundStyle(Color.craftInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !run.gates.isEmpty { GateList(gates: run.gates) }
        }
    }

    /// The counts a stage reports, by their names: "filesRead" of "filesTotal" reads as one.
    private var counts: [(String, String)] {
        guard let counts = run.progress?.counts, !counts.isEmpty else { return [] }
        var rows: [(String, String)] = []
        var used = Swift.Set<String>()
        for (part, total, label) in [("filesRead", "filesTotal", "Files"), ("looked", "pieces", "Pieces"),
                                     ("unitsPassed", "units", "Units")] {
            if let done = counts[part], let all = counts[total] {
                rows.append((label, "\(done) of \(all)"))
                used.formUnion([part, total])
            }
        }
        for key in counts.keys.sorted() where !used.contains(key) {
            rows.append((Self.label(key), counts[key]!.formatted()))
        }
        return rows
    }

    /// "useCases" → "Use cases".
    static func label(_ key: String) -> String {
        var words: [String] = []
        var current = ""
        for character in key {
            if character.isUppercase, !current.isEmpty { words.append(current); current = "" }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        let sentence = words.joined(separator: " ").lowercased()
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }

    private var modelLine: String? {
        switch run.model {
        case .loading(let role)?: return "Loading the \(Self.name(role))…"
        case .ready(let role, let seconds)?: return "The \(Self.name(role)) is in memory (loaded in \(CraftFormat.fine(seconds)))"
        case .released?: return "No model in memory"
        case nil: return nil
        }
    }

    static func name(_ role: ForgeModelRole) -> String {
        let spec = ModelCatalog.spec(role.kind)
        return (role == .coder ? "coding model, " : "vision model, ") + spec.name
    }
}

/// What a generation from an earlier launch says of itself, when no run is live.
struct RecordFacts: View {
    let record: CraftedCore.Generation

    var body: some View {
        VStack(alignment: .leading, spacing: .layer3) {
            SectionLabel("Where it stands")
            FlowLayout(spacing: .layer5, lineSpacing: .layer3) {
                CraftStat(value: "\(Int(((record.fraction ?? 0) * 100).rounded()))%", label: "Done")
                CraftStat(value: word, label: "Status")
            }
            if let stage = record.stage { FieldRow(label: "Stage", value: stage, mono: false) }
            FieldRow(label: "From", value: CraftFormat.tilde(record.source))
            FieldRow(label: "Updated", value: CraftFormat.ago(record.updated), mono: false)
            if record.status.isLive || record.status == .interrupted {
                Text("It stopped before it finished. Resume picks it up from what it already worked out: nothing is asked twice.")
                    .craftType(.caption).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var word: String {
        switch record.status {
        case .generating, .choosing, .waiting, .interrupted: return "Interrupted"
        case .finished: return "Ready"
        case .failed: return "Failed"
        }
    }
}

/// The gates a package passed (or did not): the store's rules, the ship scan, the build.
struct GateList: View {
    let gates: [GateResult]

    var body: some View {
        VStack(alignment: .leading, spacing: .layer1) {
            SectionLabel("Checks")
            ForEach(gates, id: \.self) { gate in
                HStack(alignment: .firstTextBaseline, spacing: .layer2) {
                    Image(systemName: gate.skipped ? "minus.circle" : gate.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.craftGlyph(.caption))
                        .foregroundStyle(gate.skipped ? Color.craftInkDim : gate.passed ? Color.craftSuccess : Color.craftError)
                    VStack(alignment: .leading, spacing: .hairline) {
                        Text(gate.name.prefix(1).uppercased() + gate.name.dropFirst() + (gate.skipped ? " (not run here)" : ""))
                            .craftType(.labelStrong).foregroundStyle(Color.craftInk)
                        ForEach(Array(gate.detail.prefix(4).enumerated()), id: \.offset) { _, line in
                            Text(line).craftType(.caption).foregroundStyle(Color.craftInkDim)
                                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}
