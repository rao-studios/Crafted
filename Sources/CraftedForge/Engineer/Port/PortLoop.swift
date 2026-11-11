//  WHAT: One unit, one file, one attempt at a time: the coder writes the file, it climbs the ladder in the scratch tree
//        (scan, parse, build its target, then its vectors or its canonical call), and a pass promotes it into the last
//        good tree. A fail climbs the strategy ladder (PortStrategy) under the anti-thrash rules (ThrashGuard), until it
//        passes or its budget is spent and it is parked.
//  IN:   A PortTask, the work tree, the toolchain, the run's budget (ForgeOptions.unitAttempts).
//  OUT:  The passing body, or the last failure; unit events (started, attempt, built, tested, passed, parked).
//  PIN:  NEVER THE SAME ATTEMPT TWICE. A prompt hash is never resent, a body hash is never recompiled (its first failure
//        stands), and a diagnostic fingerprint met twice within a strategy ends the strategy.

import Foundation

struct PortLoop {
    enum Outcome: Sendable {
        case passed(body: String, attempts: Int, strategy: PortStrategy)
        case parked(last: AttemptFailure?, attempts: Int)
    }

    let context: ForgeContext
    let tree: WorkTree
    let toolchain: any ForgeToolchain
    let budget: Int

    var ask: EngineerAsk { EngineerAsk(context: context) }

    func port(_ task: PortTask, round: Int = 1, guard initial: ThrashGuard = ThrashGuard()) async throws -> (Outcome, ThrashGuard) {
        var memory = initial
        var attempts = 0
        var last: AttemptFailure?
        var lastBody: String?
        var used: [PortStrategy: Int] = [:]
        var rung = 0
        context.emit(.unit(UnitEvent(unit: task.name, phase: .started, detail: task.kind.rawValue)))
        while attempts < budget, rung < PortStrategy.ladder.count {
            try context.checkCancellation()
            let strategy = PortStrategy.ladder[rung]
            if used[strategy, default: 0] >= cap(strategy, task) || (strategy == .repair && last == nil) || (strategy == .split && task.kind != .unit) {
                rung += 1; continue
            }
            let body: String
            if strategy == .split {
                guard let composed = try await split(task, last: last, round: round, memory: &memory, attempts: &attempts) else { rung += 1; continue }
                body = composed
                used[strategy] = cap(strategy, task)
            } else {
                let prompt = try task.prompt(strategy, last: last, body: lastBody, round: round)
                guard memory.send(prompt) else { rung += 1; continue }
                attempts += 1
                used[strategy, default: 0] += 1
                context.emit(.unit(UnitEvent(unit: task.name, phase: .attempt, attempt: attempts, strategy: strategy.rawValue)))
                body = SwiftCode.extract(try await ask.text(prompt, budget: strategy == .repair ? .repair : .unit))
            }
            if let known = memory.failure(of: body) {
                // The same file again: not compiled twice, and the strategy is not helping.
                last = known; lastBody = body
                rung += 1
                continue
            }
            if let failure = try await climb(task, body, attempt: attempts) {
                memory.record(body, failure)
                context.note("\(task.name), attempt \(attempts) (\(strategy.rawValue)): failed at \(failure.rung): " + (failure.lines.first ?? ""))
                let repeated = memory.repeats(failure, in: strategy)
                last = failure; lastBody = body
                // A first write hands over to repair; a strategy that meets the same failure twice is not helping.
                if strategy == .write || strategy == .split || repeated { rung += 1 }
                continue
            }
            context.emit(.unit(UnitEvent(unit: task.name, phase: .passed, attempt: attempts, strategy: strategy.rawValue)))
            return (.passed(body: body, attempts: attempts, strategy: strategy), memory)
        }
        context.emit(.unit(UnitEvent(unit: task.name, phase: .parked, attempt: attempts, detail: last?.lines.first)))
        return (.parked(last: last, attempts: attempts), memory)
    }

    func cap(_ strategy: PortStrategy, _ task: PortTask) -> Int {
        strategy == .split ? max(task.functions.count, 1) : strategy.cap
    }

    /// The unit written one function at a time, then composed; nil when there is nothing new to ask.
    func split(_ task: PortTask, last: AttemptFailure?, round: Int, memory: inout ThrashGuard, attempts: inout Int) async throws -> String? {
        guard task.functions.count > 1 else { return nil }
        var bodies: [String] = []
        for function in task.functions {
            guard attempts < budget else { return nil }
            let prompt = try task.prompt(.split, last: last, body: nil, function: function, round: round)
            guard memory.send(prompt) else { return nil }
            attempts += 1
            context.emit(.unit(UnitEvent(unit: task.name, phase: .attempt, attempt: attempts, strategy: PortStrategy.split.rawValue, detail: function.name)))
            var body = SwiftCode.extract(try await ask.text(prompt, budget: .unit))
            body = body.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.hasPrefix("import ") }.joined(separator: "\n")
            bodies.append(body.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return task.composed(bodies)
    }

    /// The ladder, cheapest rung first: nil when the body passes every rung.
    func climb(_ task: PortTask, _ body: String, attempt: Int) async throws -> AttemptFailure? {
        let scan = StaticScan.problems(body, kind: task.kind, declares: task.declares)
        if !scan.isEmpty { return AttemptFailure(rung: "scan", lines: scan, hint: "Keep to the contract: Foundation only, no files, network, processes or printing.") }
        let shape = ShapeCheck.problems(body)
        if !shape.isEmpty { return AttemptFailure(rung: "parse", lines: shape, hint: RepairHints.hint(for: ["expected"])) }
        return try await tree.trying(task.templatePath, body) {
            let build = try await toolchain.build(package: tree.scratch, target: tree.stamped(task.target), scratch: context.run.buildScratch)
            guard build.succeeded else { return DiagnosticTrim.build(build, candidate: try tree.path(task.templatePath), text: body) }
            context.emit(.unit(UnitEvent(unit: task.name, phase: .built, attempt: attempt)))
            let test = try await toolchain.test(package: tree.scratch, filter: tree.stamped(task.filter), scratch: context.run.buildScratch)
            guard test.succeeded, test.failures.isEmpty else { return DiagnosticTrim.test(test, candidate: try tree.path(task.templatePath), text: body) }
            // A filter that ran nothing proves nothing.
            guard test.passed > 0 else { return AttemptFailure(rung: "test", lines: ["no test ran for \(tree.stamped(task.filter)): the file may not declare what the tests call"]) }
            context.emit(.unit(UnitEvent(unit: task.name, phase: .tested, attempt: attempt, detail: "\(test.passed) passed")))
            return nil
        }
    }
}
