import CraftedCore
import CraftedForge
import CraftedRuntime
import Granite
import SwiftUI

extension GenerationPage {
    var view: some View {
        let run = forge.state.live(id)
        let record = library.state.generation(id)
        let title = library.state.listings[id]?.name ?? record?.title ?? "A new generation"
        return VStack(alignment: .leading, spacing: .layer4) {
            PageBar(title: title, subtitle: subtitle(run: run, record: record)) {
                Button("Listing & icon") { _state.showsListing.wrappedValue.toggle() }
                    .buttonStyle(.craftQuiet)
                    .disabled(record == nil)
                    .accessibilityIdentifier("generation.listing")
                if let run, run.phase.isLive {
                    Button(run.cancelling ? "Stopping…" : "Cancel") { forge.cancel(id) }
                        .buttonStyle(.craftQuiet)
                        .disabled(run.cancelling)
                } else if canResume(run: run, record: record) {
                    Button("Resume") { CraftedAppRoot.shared.resume(id) }.buttonStyle(.craft)
                }
            }
            HStack(alignment: .top, spacing: .layer5) {
                RunPainting(run: run, fallback: record?.fraction ?? 0, stage: run?.currentStage?.title ?? record?.stage)
                    .frame(minWidth: CraftLayout.Run.paintingMin, maxWidth: .infinity, maxHeight: .infinity)
                ScrollView {
                    VStack(alignment: .leading, spacing: .layer4) {
                        if let run {
                            StageList(run: run)
                            RunFacts(run: run)
                        } else if let record {
                            RecordFacts(record: record)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: CraftLayout.Run.stageColumn)
            }
            .frame(maxHeight: .infinity)
            if let decision = run?.decision {
                DecisionCard(decision: decision)
                    .id(decision.id)
            }
            if let failure = failure(run: run, record: record) {
                FailureCard(reason: failure, resumable: canResume(run: run, record: record))
            }
        }
        .padding(.layer5)
        .padding(.top, .layer4)
        .overlay(alignment: .trailing) {
            if state.showsListing {
                ListingPanel(id: id, fraction: run?.fraction ?? record?.fraction ?? 0, live: run?.phase.isLive == true)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.showsListing)
        .onBubble {
            On(.decisionAnswer, DecisionReply.self) { reply in forge.decide(reply.decision, reply.answer, in: id) }
            On(.failureResume) { CraftedAppRoot.shared.resume(id) }
            On(.failureFinder) { CraftedAppRoot.shared.showInFinder(id) }
            On(.pageBarBack) { CraftedAppRoot.shared.showLibrary() }
            On(.listingPanelClose) { _state.showsListing.wrappedValue = false }
        }
    }

    private func subtitle(run: LiveRun?, record: CraftedCore.Generation?) -> String {
        let role = (run?.role ?? record?.role)?.title ?? ""
        let source = record?.sourceName ?? ""
        return [role, source].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func canResume(run: LiveRun?, record: CraftedCore.Generation?) -> Bool {
        if let run { return run.phase == .failed || run.phase == .cancelled }
        guard let record else { return false }
        return record.status == .failed || record.status == .interrupted || record.status.isLive
    }

    private func failure(run: LiveRun?, record: CraftedCore.Generation?) -> String? {
        if let run { return run.phase == .failed ? (run.failure?.reason ?? "The run stopped.") : nil }
        guard let record, record.status == .failed else { return nil }
        return record.failure ?? "The run stopped."
    }
}

/// The run's painting: the gardens washing in. The drawn wash eases toward WashProgress's target at 20 fps while the
/// run is live; a finished run is the painting itself.
struct RunPainting: View {
    let run: LiveRun?
    let fallback: Double
    let stage: String?
    @State private var shown: Double = 0
    @State private var last = Date()

    var body: some View {
        PaperLeaf(cornerRadius: 12) {
            ZStack(alignment: .topLeading) {
                if run?.phase.isLive == true {
                    TimelineView(.periodic(from: .now, by: 0.05)) { context in
                        ScenePainting(scene: .gardens, progress: shown, animated: true)
                            .onChange(of: context.date) { _, now in step(now) }
                    }
                } else {
                    ScenePainting(scene: .gardens, progress: finished ? nil : max(fallback, run?.fraction ?? 0), animated: true)
                }
                if let stage, run?.phase.isLive == true {
                    HStack(spacing: .layer2) {
                        CraftedMark(size: 18, animated: true)
                        Text(stage).craftType(.title).foregroundStyle(WatercolourPalette.ink)
                    }
                    .padding(.layer4)
                }
            }
        }
        .onAppear { shown = run?.fraction ?? fallback }
    }

    private var finished: Bool { run?.phase == .done || (run == nil && fallback >= 1) }

    private func step(_ now: Date) {
        let dt = now.timeIntervalSince(last)
        last = now
        guard let run else { return }
        let elapsed = run.stageStarted.map { now.timeIntervalSince($0) } ?? 0
        let target = WashProgress.target(stages: run.stages, current: run.current, fraction: run.stageFraction,
                                         finished: run.finished, stageElapsed: elapsed)
        shown = WashProgress.displayed(previous: shown, target: max(target, shown), dt: min(max(dt, 0), 0.25))
    }
}
