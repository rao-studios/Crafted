//  WHAT: The install gate's half of the toolchain: install a package as Craft would (Granite's AgentInstaller, on a
//        scratch shelf), ask the runner what it carries (`--describe`), and make one call over `granite-agent/1`
//        with no host model (Granite's AgentProcess; any ask of the model is answered with an error).
//  IN:   An assembled package; a shelf folder (the run's run/shelf/).
//  OUT:  The forge's install gate: the installed word matches the listing's, and each command answers.
//  PIN:  INSTALL FROM A COPY. A folder `swift test` holds can block `swift package dump-package`, so the package is
//        copied (without .build, .swiftpm, .git) to a temporary folder named as the package, installed from there,
//        and the copy removed: the runner is self-contained once built, its resource bundles copied beside it.

import CraftedCore
import CraftedForge
import Foundation
import GraniteAgents

extension SwiftToolchain {
    public func install(package: URL, shelf: URL) async throws -> InstalledAgent {
        let fm = FileManager.default
        try fm.createDirectory(at: shelf, withIntermediateDirectories: true)
        let staging = fm.temporaryDirectory.appendingPathComponent("crafted-install-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        let copy = staging.appendingPathComponent(package.standardizedFileURL.lastPathComponent, isDirectory: true)
        try PackageExport.copyFiltered(from: package, to: copy)

        let installer = AgentInstaller(folder: shelf)
        let installation: AgentInstallation
        do {
            installation = try await withDeadline(installTimeout) { try await installer.install(.path(copy.path)) }
        } catch let error as AgentInstallError {
            throw ForgeError.stage("Install", error.description)
        } catch let passed as DeadlinePassed {
            throw ForgeError.stage("Install", "the install \(passed)")
        }
        let folder = installer.shelf.folder(of: installation)
        return InstalledAgent(name: installation.name, folder: folder, executable: installer.shelf.executable(of: installation),
                              words: installation.words)
    }

    /// `<agent> --describe`: the `entries` array the runner says, as JSON.
    public func describe(_ agent: InstalledAgent) async throws -> Data {
        let output = try await run([agent.executable.path, "--describe"], in: agent.folder, timeout: 60, agentEnvironment: true)
        for line in output.stdout.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entries = object["entries"] else { continue }
            return try JSONSerialization.data(withJSONObject: entries, options: [.sortedKeys, .withoutEscapingSlashes])
        }
        let log = output.stderr.split(separator: "\n").suffix(4).joined(separator: " ")
        throw ForgeError.stage("Describe", "\(agent.name) said no entries (exit \(output.status))" + (log.isEmpty ? "." : ": \(log)"))
    }

    /// One call to `word` in a process of its own, with the host's folder and no model.
    public func perform(_ agent: InstalledAgent, word: String, input: Data, directory: URL) async throws -> CallOutcome {
        let notes = NoteLog()
        let host = AgentHost(directory: directory.path, ask: nil, model: nil, note: { notes.add($0) })
        let process = AgentProcess(executable: agent.executable, environment: ToolProcess.cleanEnvironment())
        do {
            let output = try await withDeadline(callTimeout) {
                try await process.perform(word: word, input: input, host: host)
            }
            return CallOutcome(output: output, notes: notes.lines)
        } catch let error as AgentRemoteError {
            if case .refused(_, _, let message) = error {
                return CallOutcome(failure: message, refused: true, notes: notes.lines)
            }
            return CallOutcome(failure: error.description, notes: notes.lines)
        } catch let passed as DeadlinePassed {
            return CallOutcome(failure: "\(word) \(passed)", notes: notes.lines)
        }
    }

    func run(_ arguments: [String], in folder: URL, timeout: TimeInterval, agentEnvironment: Bool) async throws -> ToolProcess.Output {
        let environment = ToolProcess.cleanEnvironment(adding: agentEnvironment ? ["GRANITE_AGENT": "1"] : [:])
        do {
            return try await ToolProcess.run(arguments, in: folder, timeout: timeout, environment: environment)
        } catch let failure as ToolProcess.SpawnFailure {
            throw ForgeError.stage("Describe", failure.description)
        }
    }
}
