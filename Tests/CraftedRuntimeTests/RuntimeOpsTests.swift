//  WHAT: The runtime services' transitions as values: each service's `apply`, the model queue's adoption, a run's
//        events folded into its state, an answer's immediate effect, the listing's edited marks. No Granite, no disk,
//        no model.

import CraftedCore
import CraftedForge
@testable import CraftedRuntime
import Foundation
import Testing

@Suite struct ModelOpsTests {
    private func state(vision: Bool = false, coder: Bool = false, physicalGB: Int = 128, free: Int64? = 500_000_000_000) -> ModelService.Center.State {
        var state = ModelService.Center.State()
        state.statuses = [
            vision ? ModelStatus(kind: .vision, installed: true, path: "/m/v") : .missing(.vision),
            coder ? ModelStatus(kind: .coder, installed: true, path: "/m/c") : .missing(.coder),
        ]
        state.fit = MachineFit(physicalGB: physicalGB, freeDiskBytes: free)
        return state
    }

    @Test func downloadBothQueuesInCatalogOrderAndStartsVision() {
        var s = state()
        let run = UUID()
        ModelOps.request([.coder, .vision], run: run, allowLowMemory: false, in: &s)
        #expect(s.downloading == ModelDownload(kind: .vision, fraction: 0))
        #expect(s.downloadRun == run)
        #expect(s.queue == [.coder])
    }

    @Test func aSecondRequestQueuesInsteadOfStarting() {
        var s = state()
        let first = UUID()
        ModelOps.request([.vision], run: first, allowLowMemory: false, in: &s)
        ModelOps.request([.coder], run: UUID(), allowLowMemory: false, in: &s)
        #expect(s.downloadRun == first)
        #expect(s.downloading?.kind == .vision)
        #expect(s.queue == [.coder])
    }

    @Test func anInstalledModelIsNeverQueued() {
        var s = state(vision: true)
        ModelOps.request([.vision, .coder], run: UUID(), allowLowMemory: false, in: &s)
        #expect(s.downloading?.kind == .coder)
        #expect(s.queue.isEmpty)
    }

    @Test func aSmallMacIsRefusedTheCoderUnlessAllowed() {
        var s = state(physicalGB: 32)
        ModelOps.request([.coder], run: UUID(), allowLowMemory: false, in: &s)
        #expect(s.downloading == nil)
        #expect(s.problem?.contains("48 GB") == true)
        var allowed = state(physicalGB: 32)
        ModelOps.request([.coder], run: UUID(), allowLowMemory: true, in: &allowed)
        #expect(allowed.downloading?.kind == .coder)
    }

    @Test func aFullDiskIsRefused() {
        var s = state(free: 1_000_000_000)
        ModelOps.request([.vision], run: UUID(), allowLowMemory: false, in: &s)
        #expect(s.downloading == nil)
        #expect(s.problem != nil)
    }

    @Test func theEndOfAnotherRunIsIgnoredAndTheEndOfThisOneFreesTheSlot() {
        var s = state()
        let run = UUID()
        ModelOps.request([.vision, .coder], run: run, allowLowMemory: false, in: &s)
        ModelOps.apply(.downloadEnded(run: UUID()), to: &s)
        #expect(s.downloading != nil)
        ModelOps.apply(.downloadEnded(run: run), to: &s)
        #expect(s.downloading == nil && s.downloadRun == nil)
        // The empty request the end sends takes the next one.
        let next = UUID()
        ModelOps.request([], run: next, allowLowMemory: false, in: &s)
        #expect(s.downloading?.kind == .coder && s.downloadRun == next && s.queue.isEmpty)
    }

    @Test func progressOnlyMovesTheModelDownloading() {
        var s = state()
        ModelOps.request([.vision], run: UUID(), allowLowMemory: false, in: &s)
        ModelOps.apply(.progress(.coder, 0.5), to: &s)
        #expect(s.downloading?.fraction == 0)
        ModelOps.apply(.progress(.vision, 0.5), to: &s)
        #expect(s.downloading?.fraction == 0.5)
    }

    @Test func aReadDropsWhatIsNowOnDiskFromTheQueue() {
        var s = state()
        s.queue = [.coder]
        ModelOps.apply(.read([ModelStatus(kind: .vision, installed: true), ModelStatus(kind: .coder, installed: true)],
                             MachineFit(physicalGB: 128, freeDiskBytes: nil)), to: &s)
        #expect(s.queue.isEmpty && s.bothReady && s.hasRead)
    }
}

@Suite struct ForgeOpsTests {
    let stages = [
        ForgeStage(id: "walk", title: "Walking", part: .analysis, weight: 1),
        ForgeStage(id: "interpret", title: "Interpreting", part: .analysis, weight: 1),
        ForgeStage(id: "port", title: "Porting", part: .generation, weight: 2),
    ]

    private func folded(_ events: [ForgeEvent]) -> LiveRun {
        var state = ForgeService.Center.State()
        ForgeOps.apply(.began(id: "g", role: .engineer), to: &state)
        for event in events { ForgeOps.apply(.event(id: "g", event), to: &state) }
        return state.run!
    }

    @Test func aRunIsAFoldOfItsEvents() {
        let card = InterpretationCard(id: 0, archetype: .whole, name: "Units", word: "units", summary: "", commands: [])
        var run = folded([.stages(stages), .stageStarted("walk"), .stageFinished("walk", summary: "12 files"),
                          .stageStarted("interpret"), .interpretations(round: 0, cards: [card])])
        #expect(run.phase == .choosing)
        #expect(run.cards.count == 1)
        #expect(run.summaries["walk"] == "12 files")
        #expect(abs(run.fraction - 0.25) < 0.0001)
        ForgeOps.answered(.choose(0), in: &run)
        #expect(run.phase == .generating)
    }

    @Test func aGenerationStageMovesThePhaseOn() {
        let run = folded([.stages(stages), .stageStarted("port")])
        #expect(run.phase == .generating)
        #expect(run.stageStarted != nil)
    }

    @Test func completionIsDoneAndWhole() {
        let report = PackageReport(package: URL(fileURLWithPath: "/tmp/p"), identity: AgentIdentity.derive(display: "Units"),
                                   fileCount: 3, gates: [], built: false)
        let run = folded([.stages(stages), .stageStarted("walk"), .completed(report)])
        #expect(run.phase == .done && run.fraction == 1 && run.report == report && run.ended != nil)
    }

    @Test func aStreamThatEndsWithoutSayingHowIsAnInterruption() {
        var state = ForgeService.Center.State()
        ForgeOps.apply(.began(id: "g", role: .designer), to: &state)
        ForgeOps.apply(.event(id: "g", .stages(stages)), to: &state)
        ForgeOps.apply(.ended(id: "g"), to: &state)
        #expect(state.run?.phase == .cancelled)
        #expect(!state.isBusy)
    }

    @Test func anotherRunsEventIsDropped() {
        var state = ForgeService.Center.State()
        ForgeOps.apply(.began(id: "g", role: .designer), to: &state)
        ForgeOps.apply(.event(id: "other", .failed(ForgeFailure(reason: "no"))), to: &state)
        #expect(state.run?.phase == .analysing)
    }

    @Test func answeringAQuestionClearsItAtOnce() {
        let decision = Decision(id: "fonts", kind: .fontRights, question: "?", options: [], defaultOption: "keep")
        var run = folded([.stages(stages), .decision(decision)])
        #expect(run.decision == decision)
        ForgeOps.answered(.decide("fonts", DecisionAnswer(option: "keep")), in: &run)
        #expect(run.decision == nil)
    }

    @Test func aStartFailureClearsOnlyItsOwnAdoption() {
        var state = ForgeService.Center.State()
        let mine = UUID()
        state.starting = mine
        ForgeOps.apply(.startFailed(request: UUID(), "other"), to: &state)
        #expect(state.starting == mine)
        ForgeOps.apply(.startFailed(request: mine, "mine"), to: &state)
        #expect(state.starting == nil && state.problem == "mine")
    }

    @Test func anExportEndsItsSlot() {
        var state = ForgeService.Center.State()
        state.exporting = "g"
        state.exportRequest = UUID()
        ForgeOps.apply(.exported(id: "g", ExportOutcome(archive: "/tmp/a.zip", report: nil, failure: nil)), to: &state)
        #expect(state.exporting == nil && state.exportRequest == nil && state.exports["g"]?.archive == "/tmp/a.zip")
    }
}

@Suite struct LibraryOpsTests {
    @Test func aSaveMarksWhatChanged() {
        let saved = AgentListing(name: "Units", word: "units", tagline: "Converts.")
        var draft = saved
        draft.tagline = "Converts units."
        let marked = LibraryOps.marking(draft, against: saved)
        #expect(marked.edited == [.tagline])
    }

    @Test func oneEntryReplacesItsGenerationAndAGoneOneLeaves() {
        var state = LibraryService.Center.State()
        let generation = Generation(id: "a", role: .engineer, source: "/tmp/a")
        LibraryOps.apply(.one(id: "a", LibraryOps.Entry(generation: generation, listing: nil, icon: "/tmp/a/icon.png")), to: &state)
        #expect(state.generations.map(\.id) == ["a"] && state.icons["a"] == "/tmp/a/icon.png")
        LibraryOps.apply(.one(id: "a", nil), to: &state)
        #expect(state.generations.isEmpty && state.icons["a"] == nil)
    }
}

@Suite struct PreferencesOpsTests {
    @Test func theCreditIsNilWhenBlank() {
        var state = PreferencesService.Center.State()
        PreferencesOps.apply(.creditName("  "), to: &state)
        PreferencesOps.apply(.role(.designer), to: &state)
        #expect(state.credit == nil && state.role == .designer)
    }
}
