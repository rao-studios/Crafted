//  WHAT: The gates a port passes before it is offered: its own tests (record found, schema as planned, every unit's
//        vectors, every command's canonical call, no stub left); then, when asked to install, a real install from a
//        copy on a scratch shelf, `--describe` naming the word, and each command's canonical call over the wire.
//  IN:   The last good tree, the canonical calls, the toolchain.
//  OUT:  GateResults in the pipeline's outcome (the forge adds the store, ship and build gates on assembly).
//  PIN:  INSTALL FROM A COPY. A folder `swift test` holds blocks `dump-package`, so the installer gets a fresh copy.

import CraftedCore
import Foundation

struct EngineerGates {
    let context: ForgeContext
    let toolchain: any ForgeToolchain
    let tree: WorkTree

    func run(_ artefacts: PortArtefacts) async -> [GateResult] {
        var gates: [GateResult] = []
        context.progress("gates", "Running the package's own tests", fraction: 0.1)
        do {
            let result = try await toolchain.test(package: tree.package, filter: nil, scratch: context.run.buildScratch)
            let detail = result.succeeded ? ["\(result.passed) tests passed in \(Int(result.seconds)) s."]
                : result.failures.prefix(6).map { "\($0.test): \($0.message)" } + result.diagnostics.filter { $0.severity == .error }.prefix(4).map { "\($0.file):\($0.line): \($0.message)" }
            gates.append(GateResult(name: "tests", passed: result.succeeded && result.failures.isEmpty, detail: detail.isEmpty ? ["The tests failed."] : detail))
        } catch {
            gates.append(GateResult(name: "tests", passed: false, detail: [error.localizedDescription]))
        }
        context.emit(.gate(gates[gates.count - 1]))
        guard context.options.install else { return gates }
        let calls = artefacts.shipped.commands.compactMap { command in artefacts.calls[command.name].map { (command.name, $0) } }
        var step = "install"
        do {
            context.progress("gates", "Installing a copy on a scratch shelf", fraction: 0.4)
            let copy = context.run.root.appendingPathComponent("work/install/\(tree.identity.package)", isDirectory: true)
            try? FileManager.default.removeItem(at: copy.deletingLastPathComponent())
            try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: tree.package, to: copy)
            try? FileManager.default.removeItem(at: context.run.shelf)
            let agent = try await toolchain.install(package: copy, shelf: context.run.shelf)
            gates.append(GateResult(name: "install", passed: true, detail: ["Installed \(agent.name) on a scratch shelf."]))
            context.emit(.gate(gates[gates.count - 1]))
            step = "describe"
            let described = try await toolchain.describe(agent)
            let text = String(decoding: described, as: UTF8.self)
            let named = text.contains("\"\(tree.identity.word)\"")
            gates.append(GateResult(name: "describe", passed: named,
                                    detail: [named ? "--describe names \(tree.identity.word)." : "--describe does not name \(tree.identity.word)."]))
            context.emit(.gate(gates[gates.count - 1]))
            for (index, (command, call)) in calls.enumerated() {
                step = "call \(command)"
                context.progress("gates", "Calling \(command) over the wire", fraction: 0.6 + 0.4 * Double(index) / Double(max(calls.count, 1)))
                let folder = context.run.root.appendingPathComponent("work/calls/\(command)", isDirectory: true)
                try? FileManager.default.removeItem(at: folder)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for (path, text) in call.files ?? [:] {
                    let url = folder.appendingPathComponent(path)
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try Data(text.utf8).write(to: url)
                }
                var input = call.input
                input["directory"] = .string(folder.path)
                let outcome = try await toolchain.perform(agent, word: tree.identity.word, input: try JSONValue.object(input).data(), directory: folder)
                let detail = outcome.succeeded ? ["\(command) answered over the wire."] : [outcome.failure ?? "\(command) did not answer."]
                gates.append(GateResult(name: "call \(command)", passed: outcome.succeeded, detail: detail + outcome.notes.prefix(2)))
                context.emit(.gate(gates[gates.count - 1]))
            }
        } catch {
            gates.append(GateResult(name: step, passed: false, detail: [error.localizedDescription]))
            context.emit(.gate(gates[gates.count - 1]))
        }
        return gates
    }
}
