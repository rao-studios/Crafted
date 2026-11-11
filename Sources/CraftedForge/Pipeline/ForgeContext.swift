//  WHAT: Everything a pipeline's stage may touch: the folder it reads, the run folder it writes, the models through
//        the structured ask, the toolchain, the ledger and caches, and the person (events out; choices and answers
//        back).
//  IN:   ForgeRun, which makes one per generation run.
//  OUT:  DesignerPipeline, EngineerPipeline and their stages.
//  PIN:  STAGES TALK THROUGH THE CONTEXT ONLY. Nothing in a pipeline holds the run, the store or the UI, so every
//        stage runs the same under the app, crafted-check and a test.

import CraftedCore
import Foundation

public final class ForgeContext: @unchecked Sendable {
    public let id: String
    public let role: CraftedRole
    /// The dropped folder. Read only.
    public let source: URL
    public let run: RunFolder
    public let options: ForgeOptions
    public let model: any ForgeModel
    public let toolchain: (any ForgeToolchain)?
    public let templates: TemplateSource
    public let home: CraftedHome
    /// The run's own answers and choices.
    public let ledger: Ledger
    /// Answers shared by every generation: cards, looks, measures.
    public let cache: SharedCache
    public let ask: StructuredAsk

    private let sink: @Sendable (ForgeEvent) -> Void
    private let decider: @Sendable (Decision) async throws -> DecisionAnswer
    private let chooser: @Sendable ([InterpretationCard], Int) async throws -> InterpretationChoice
    private let rate: RateBox

    public init(id: String, role: CraftedRole, source: URL, run: RunFolder, options: ForgeOptions, model: any ForgeModel,
                toolchain: (any ForgeToolchain)?, templates: TemplateSource, home: CraftedHome,
                sink: @escaping @Sendable (ForgeEvent) -> Void,
                decider: @escaping @Sendable (Decision) async throws -> DecisionAnswer,
                chooser: @escaping @Sendable ([InterpretationCard], Int) async throws -> InterpretationChoice) {
        self.id = id; self.role = role; self.source = source; self.run = run; self.options = options; self.model = model
        self.toolchain = toolchain; self.templates = templates; self.home = home
        self.ledger = Ledger(folder: run.ledger)
        self.cache = SharedCache(root: home.cache)
        self.sink = sink; self.decider = decider; self.chooser = chooser
        let rate = RateBox()
        self.rate = rate
        self.ask = StructuredAsk(model: model, calls: run.calls, onReply: { reply in rate.track(reply) })
    }

    // MARK: Saying

    public func emit(_ event: ForgeEvent) { sink(event) }
    public func started(_ stage: String) { sink(.stageStarted(stage)) }
    public func finished(_ stage: String, _ summary: String) { sink(.stageFinished(stage, summary: summary)) }
    public func note(_ text: String) { sink(.note(text)) }
    public func finding(_ finding: Finding) { sink(.finding(finding)) }

    public func progress(_ stage: String, _ detail: String, fraction: Double? = nil, counts: [String: Int] = [:]) {
        sink(.progress(ForgeProgress(stage: stage, detail: detail, fraction: fraction, counts: counts, tokensPerSecond: rate.last)))
    }

    // MARK: Models

    /// Makes `role` resident, saying so: the first load of the coder takes tens of seconds.
    public func use(_ role: ForgeModelRole) async throws {
        if await model.resident() == role { return }
        sink(.model(.loading(role)))
        let start = Date()
        try await model.prepare(role)
        sink(.model(.ready(role, seconds: Date().timeIntervalSince(start))))
    }

    // MARK: Asking the person

    public func decide(_ decision: Decision) async throws -> DecisionAnswer {
        if options.autoDecide { return DecisionAnswer(option: decision.defaultOption) }
        if let kept = ledger.get(DecisionAnswer.self, "decision-" + decision.id) { return kept }
        let answer = try await decider(decision)
        try? ledger.put(answer, "decision-" + decision.id)
        return answer
    }

    public func choose(_ cards: [InterpretationCard], round: Int) async throws -> InterpretationChoice {
        if let index = options.autoChoose { return .pick(min(max(index, 0), max(cards.count - 1, 0))) }
        return try await chooser(cards, round)
    }

    public func checkCancellation() throws { try Task.checkCancellation() }
}

/// The last reply's decode rate, for the progress line.
final class RateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Double?

    var last: Double? { lock.withLock { value } }

    func track(_ reply: ModelReply) {
        guard let rate = reply.tokensPerSecond else { return }
        lock.withLock { value = rate }
    }
}
