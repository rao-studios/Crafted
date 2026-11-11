//  WHAT: The last gate before a package is offered: installed as Craft installs it (Granite's AgentInstaller, on a
//        scratch shelf), asked what it carries (`--describe` must say the listing's word), and called once per
//        command over the wire with no host model. One GateResult, one sentence per step.
//  IN:   A toolchain, the assembled package, the identity, and the calls to make (a command's canonical input).
//  OUT:  The pipelines put it in PipelineOutcome.gates; Forge.assemble carries it into the report.
//  PIN:  THE SHELF IS SCRATCH. The installation is removed when the gate ends, pass or fail: a run's folder never
//        keeps a built runner.
//  PIN:  A REFUSAL CAN BE RIGHT. A call that expects one (a command with no model, asked in words) passes when the
//        agent refuses, and fails when it answers.

import CraftedCore
import Foundation

public enum InstallGate {
    public static let name = "install"

    public struct Call: Sendable, Equatable {
        /// What the detail calls it: "convert".
        public var name: String
        /// The input JSON, as a host model would write it.
        public var input: Data
        /// Whether a refusal is the right answer.
        public var expectRefusal: Bool

        public init(name: String, input: Data, expectRefusal: Bool = false) {
            self.name = name; self.input = input; self.expectRefusal = expectRefusal
        }
    }

    public static func check(toolchain: any ForgeToolchain, package: URL, shelf: URL, identity: AgentIdentity,
                             calls: [Call], directory: URL) async throws -> GateResult {
        guard await toolchain.version() != nil else {
            return GateResult(name: name, passed: false, detail: ["No Swift toolchain on this Mac: not installed here."], skipped: true)
        }
        var detail: [String] = []
        let agent: InstalledAgent
        do {
            agent = try await toolchain.install(package: package, shelf: shelf)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return GateResult(name: name, passed: false, detail: ["It did not install as Craft installs it: \(error.localizedDescription)"])
        }
        defer { try? FileManager.default.removeItem(at: agent.folder) }
        var passed = true

        let described = (try? await toolchain.describe(agent))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] }?
            .compactMap { $0["word"] as? String } ?? []
        if described.contains(identity.word) {
            detail.append("Installed as \(agent.name); --describe says $\(identity.word).")
        } else {
            passed = false
            detail.append("Installed as \(agent.name), but --describe says \(described.isEmpty ? "nothing" : described.map { "$" + $0 }.joined(separator: ", ")), not $\(identity.word): assemble it again.")
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for call in calls {
            try Task.checkCancellation()
            let outcome = try await toolchain.perform(agent, word: identity.word, input: call.input, directory: directory)
            switch (outcome.succeeded, outcome.refused, call.expectRefusal) {
            case (true, _, false):
                detail.append("\(call.name) answered.")
            case (false, true, true):
                detail.append("\(call.name) refused, as it should.")
            case (true, _, true):
                passed = false
                detail.append("\(call.name) answered where it should refuse: it must not guess without the host's model.")
            default:
                passed = false
                detail.append("\(call.name) failed: \(outcome.failure ?? "no answer").")
            }
        }
        return GateResult(name: name, passed: passed, detail: detail)
    }
}
