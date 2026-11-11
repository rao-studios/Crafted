//  WHAT: The forge service's decisions as values: the writer's mutation, how each of a run's events changes the run,
//        what an answer clears at once — and the one piece of work, the consumer of a run's events.
//  OUT:  ForgeService's reducers.
//  PIN:  `apply`, `applyEvent` and `answered` are pure: a run's whole state is a fold of its events.
//  PIN:  PROGRESS IS COALESCED, NOTHING ELSE. A run may say progress hundreds of times a second while it reads files;
//        the consumer passes at most one every 100 ms (the latest), and flushes the held one before any other event so
//        order is kept.

import CraftedCore
import CraftedForge
import Foundation

public enum ForgeOps {
    public static func apply(_ kind: ForgeService.Set.Meta.Kind, to state: inout ForgeService.Center.State) {
        switch kind {
        case .began(let id, let role):
            state.run = LiveRun(id: id, role: role)
            state.starting = nil
            state.problem = nil
        case .startFailed(let request, let reason):
            if state.starting == request { state.starting = nil }
            state.problem = reason
        case .event(let id, let event):
            guard var run = state.run, run.id == id else { return }
            applyEvent(event, to: &run)
            state.run = run
        case .ended(let id):
            guard var run = state.run, run.id == id else { return }
            // A stream that ended without saying how is an interruption: Resume picks it up.
            if run.phase.isLive {
                run.phase = .cancelled
                run.ended = Date()
            }
            run.cancelling = false
            state.run = run
        case .exported(let id, let outcome):
            state.exports[id] = outcome
            if state.exporting == id {
                state.exporting = nil
                state.exportRequest = nil
            }
        case .problem(let text):
            state.problem = text
        case .reset:
            state = .init()
        }
    }

    /// One event into the run.
    public static func applyEvent(_ event: ForgeEvent, to run: inout LiveRun) {
        switch event {
        case .stages(let stages):
            run.stages = stages
        case .stageStarted(let stage):
            run.current = stage
            run.stageStarted = Date()
            if run.phase.isLive {
                run.phase = run.stages.first { $0.id == stage }?.part == .generation ? .generating : .analysing
            }
        case .stageFinished(let stage, let summary):
            run.finished.insert(stage)
            run.summaries[stage] = summary
        case .progress(let progress):
            run.progress = progress
            if let rate = progress.tokensPerSecond { run.tokensPerSecond = rate }
        case .model(let activity):
            run.model = activity
        case .finding(let finding):
            run.findings.append(finding)
            if run.findings.count > 200 { run.findings.removeFirst(run.findings.count - 200) }
        case .interpretations(let round, let cards):
            run.cards = cards
            run.round = round
            if run.phase.isLive { run.phase = .choosing }
        case .decision(let decision):
            run.decision = decision
        case .unit(let unit):
            run.units[unit.unit] = unit
        case .gate(let gate):
            run.gates.removeAll { $0.name == gate.name }
            run.gates.append(gate)
        case .listing:
            run.listingRevision += 1
        case .note(let note):
            run.notes.append(note)
            if run.notes.count > 100 { run.notes.removeFirst(run.notes.count - 100) }
        case .completed(let report):
            run.report = report
            run.phase = .done
            run.decision = nil
            run.current = nil
            run.ended = Date()
            run.cancelling = false
        case .failed(let failure):
            run.failure = failure
            run.phase = .failed
            run.decision = nil
            run.ended = Date()
            run.cancelling = false
        case .cancelled:
            run.phase = .cancelled
            run.decision = nil
            run.ended = Date()
            run.cancelling = false
        }
        run.fraction = run.phase == .done ? 1
            : ForgeStage.overall(run.stages, current: run.current, fraction: run.stageFraction, finished: run.finished)
    }

    /// What an answer clears at once, before the run hears it: the cards (now generating) or the question.
    public static func answered(_ reply: ForgeService.Answer.Meta.Reply, in run: inout LiveRun) {
        switch reply {
        case .choose:
            run.phase = .generating
        case .steer:
            run.phase = .analysing
            run.cards = []
        case .decide(let decision, _):
            if run.decision?.id == decision { run.decision = nil }
        }
    }

    /// Whether an event changes the generation's record on disk (and the grid should read it again).
    static func touchesRecord(_ event: ForgeEvent) -> Bool {
        switch event {
        case .stageStarted, .stageFinished, .interpretations, .decision, .listing, .completed, .failed, .cancelled: return true
        default: return false
        }
    }

    // MARK: - The consumer

    /// Every event of `run` into the service's state, in order, progress coalesced; the grid refreshed as records
    /// change. Ends when the run's stream does.
    static func consume(_ run: ForgeRun, service: ForgeService, library: LibraryService) async {
        let id = run.id
        let coalescer = ProgressCoalescer { progress in service.set(.event(id: id, .progress(progress))) }
        for await event in run.events {
            if case .progress(let progress) = event {
                await coalescer.offer(progress)
                continue
            }
            await coalescer.flush()
            service.set(.event(id: id, event))
            if touchesRecord(event) { library.refreshSoon() }
        }
        await coalescer.flush()
        service.set(.ended(id: id))
        ForgeService.live.remove(id)
        ForgeService.runs.finish(id)
        // The run's record keeper writes after the event it follows: read the folder once more when it has caught up.
        try? await Task.sleep(nanoseconds: 400_000_000)
        library.refreshSoon()
    }
}

/// Holds the latest progress and passes at most one every `interval`; `flush` passes a held one at once.
actor ProgressCoalescer {
    private let send: @Sendable (ForgeProgress) -> Void
    private let interval: UInt64
    private var held: ForgeProgress?
    private var last = Date.distantPast
    private var timer: Task<Void, Never>?

    init(interval: TimeInterval = 0.1, send: @escaping @Sendable (ForgeProgress) -> Void) {
        self.send = send
        self.interval = UInt64(interval * 1_000_000_000)
    }

    func offer(_ progress: ForgeProgress) {
        if Date().timeIntervalSince(last) * 1_000_000_000 >= Double(interval), timer == nil {
            pass(progress)
            return
        }
        held = progress
        guard timer == nil else { return }
        let interval = interval
        timer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            await self?.fire()
        }
    }

    func flush() {
        timer?.cancel()
        timer = nil
        if let held { pass(held) }
    }

    private func fire() {
        timer = nil
        if let held { pass(held) }
    }

    private func pass(_ progress: ForgeProgress) {
        held = nil
        last = Date()
        send(progress)
    }
}
