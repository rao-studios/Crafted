//  WHAT: One run of one generation: the pipeline in a task of its own, its events out (to the UI, to events.jsonl,
//        to the generation's record), and the person's choices and answers back in.
//  IN:   Forge.start / resume / update.
//  OUT:  `events` (one consumer: ForgeService in the app, crafted-check in the terminal).
//  PIN:  ALWAYS RESUMABLE. A cancel, a quit or a crash leaves the generation `interrupted`; the ledger keeps every
//        answer, so Resume walks the cached stages in seconds and asks only what it had not asked.
//  PIN:  STATUS FOLLOWS EVENTS, IN ORDER. Record writes go through one serial consumer of an internal stream, so the
//        tile never shows an older stage after a newer one.

import CraftedCore
import Foundation

public actor ForgeRun {
    public nonisolated let id: String
    public nonisolated let role: CraftedRole
    /// Every event, in order. One consumer.
    public nonisolated let events: AsyncStream<ForgeEvent>

    private let continuation: AsyncStream<ForgeEvent>.Continuation
    private let records: AsyncStream<ForgeEvent>.Continuation
    private let forge: Forge
    private let pipeline: any RolePipeline
    private let source: URL
    private let options: ForgeOptions
    private var task: Task<Void, Never>?
    private var decisions: [String: CheckedContinuation<DecisionAnswer, Error>] = [:]
    private var choice: CheckedContinuation<InterpretationChoice, Error>?
    private let logLock = NSLock()

    init(id: String, role: CraftedRole, source: URL, options: ForgeOptions, forge: Forge, pipeline: any RolePipeline) {
        self.id = id
        self.role = role
        self.source = source
        self.options = options
        self.forge = forge
        self.pipeline = pipeline
        (events, continuation) = AsyncStream<ForgeEvent>.makeStream(bufferingPolicy: .unbounded)
        let (recordStream, records) = AsyncStream<ForgeEvent>.makeStream(bufferingPolicy: .unbounded)
        self.records = records
        let store = forge.store
        let stages = pipeline.stages
        Task.detached { await ForgeRun.keepRecord(id: id, stages: stages, store: store, events: recordStream) }
    }

    public var isRunning: Bool { task != nil }

    /// Starts the run. A second call does nothing.
    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in await self?.body() }
    }

    public func choose(_ index: Int) { settleChoice(.success(.pick(index))) }

    public func steer(_ text: String) { settleChoice(.success(.steer(text))) }

    public func decide(_ decisionID: String, _ answer: DecisionAnswer) {
        decisions.removeValue(forKey: decisionID)?.resume(returning: answer)
    }

    /// Stops the run; it stays resumable.
    public func cancel() {
        task?.cancel()
        settleChoice(.failure(CancellationError()))
        for (_, waiter) in decisions { waiter.resume(throwing: CancellationError()) }
        decisions = [:]
    }

    /// Waits until the run has ended.
    public func wait() async { await task?.value }

    // MARK: The run

    private func body() async {
        let run = RunFolder(root: forge.store.runURL(id))
        do {
            try run.create()
            await forge.model.bind(source: source)
            say(.stages(pipeline.stages))
            let context = ForgeContext(
                id: id, role: role, source: source, run: run, options: options, model: forge.model,
                toolchain: forge.toolchain, templates: forge.templates, home: forge.store.home,
                sink: { [weak self] event in self?.sayNow(event) },
                decider: { [weak self] decision in
                    guard let self else { throw CancellationError() }
                    return try await self.ask(decision)
                },
                chooser: { [weak self] cards, round in
                    guard let self else { throw CancellationError() }
                    return try await self.ask(cards, round: round)
                })
            let outcome = try await pipeline.generate(context)
            try Task.checkCancellation()
            let listing = try await forge.store.suggestListing(outcome.listing, id)
            say(.listing(listing))
            try await forge.store.update(id) {
                $0.summary = outcome.summary
                $0.interpretation = outcome.interpretation ?? $0.interpretation
            }
            let report = try await forge.assemble(id, options: options, extraGates: outcome.gates)
            say(.completed(report))
        } catch is CancellationError {
            say(.cancelled)
        } catch {
            if Task.isCancelled {
                say(.cancelled)
            } else {
                say(.failed(ForgeFailure(reason: error.localizedDescription)))
            }
        }
        continuation.finish()
        records.finish()
        task = nil
    }

    private func say(_ event: ForgeEvent) { sayNow(event) }

    /// From any thread: out to the consumer, the record keeper and the log, in the order said.
    nonisolated func sayNow(_ event: ForgeEvent) {
        continuation.yield(event)
        records.yield(event)
        logLock.withLock {
            let url = forge.store.runURL(id).appendingPathComponent("events.jsonl")
            if let data = try? ForgeJSON.line.encode(TimedEvent(at: Date(), event: event)),
               let line = String(data: data, encoding: .utf8) {
                try? AtomicFile.append(line: line, to: url)
            }
        }
    }

    // MARK: Waiting on the person

    private func ask(_ decision: Decision) async throws -> DecisionAnswer {
        say(.decision(decision))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (waiter: CheckedContinuation<DecisionAnswer, Error>) in
                decisions[decision.id] = waiter
            }
        } onCancel: {
            Task { await self.cancelWaiters() }
        }
    }

    private func ask(_ cards: [InterpretationCard], round: Int) async throws -> InterpretationChoice {
        say(.interpretations(round: round, cards: cards))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (waiter: CheckedContinuation<InterpretationChoice, Error>) in
                choice = waiter
            }
        } onCancel: {
            Task { await self.cancelWaiters() }
        }
    }

    private func cancelWaiters() {
        settleChoice(.failure(CancellationError()))
        for (_, waiter) in decisions { waiter.resume(throwing: CancellationError()) }
        decisions = [:]
    }

    private func settleChoice(_ result: Result<InterpretationChoice, Error>) {
        guard let waiter = choice else { return }
        choice = nil
        waiter.resume(with: result)
    }

    // MARK: The record

    private static func keepRecord(id: String, stages: [ForgeStage], store: GenerationStore, events: AsyncStream<ForgeEvent>) async {
        var finished: Swift.Set<String> = []
        for await event in events {
            switch event {
            case .stageStarted(let stage):
                let title = stages.first { $0.id == stage }?.title
                let fraction = ForgeStage.overall(stages, current: stage, fraction: 0, finished: finished)
                try? await store.update(id) { $0.status = .generating; $0.stage = title; $0.fraction = fraction; $0.failure = nil }
            case .stageFinished(let stage, _):
                finished.insert(stage)
                let fraction = ForgeStage.overall(stages, current: nil, fraction: nil, finished: finished)
                try? await store.update(id) { $0.fraction = fraction }
            case .interpretations:
                try? await store.update(id) { $0.status = .choosing }
            case .decision:
                try? await store.update(id) { $0.status = .waiting }
            case .unit, .progress:
                break
            case .completed(let report):
                try? await store.update(id) {
                    $0.status = .finished; $0.stage = nil; $0.fraction = 1; $0.identity = report.identity
                    $0.built = report.built; $0.failure = nil
                }
            case .failed(let failure):
                try? await store.update(id) { $0.status = .failed; $0.failure = failure.reason }
            case .cancelled:
                try? await store.update(id) { $0.status = .interrupted }
            default:
                break
            }
        }
    }
}

/// An event as events.jsonl keeps it.
struct TimedEvent: Codable {
    var at: Date
    var event: ForgeEvent
}
