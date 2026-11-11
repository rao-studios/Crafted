//  WHAT: `crafted-check toolchain`: the live toolchain seam by hand on any agent package, as the forge's gates use
//        it: the version, a build, the tests, an install on a scratch shelf, `--describe`, and one call over the wire
//        with no host model. The package is copied first, so the original is never built in or written to.
//  OUT:  Exit 0 when every step that ran passed.

import CraftedCore
import CraftedForge
import CraftedToolchain
import Foundation

enum ToolchainCommand {
    static let usage = """
    crafted-check toolchain [--target T] [--filter F] [--no-test] [--no-install] [--word W] [--input JSON|@file]
                            [--directory DIR] [--keep] <package>
    """

    static func run(_ arguments: CheckArguments) async -> Int32 {
        let source: URL
        do { source = try arguments.folder() } catch { return ForgeCommand.fail("\(error)\n\n" + usage) }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("crafted-toolchain-\(UUID().uuidString.prefix(8))", isDirectory: true)
        defer { if !arguments.has("keep") { try? fm.removeItem(at: work) } }
        let package = work.appendingPathComponent(source.lastPathComponent, isDirectory: true)
        let scratch = work.appendingPathComponent("scratch", isDirectory: true)
        let shelf = work.appendingPathComponent("shelf", isDirectory: true)
        do { try PackageExport.copyFiltered(from: source, to: package) } catch { return ForgeCommand.fail("Copy failed: \(error)") }

        let toolchain = SwiftToolchain()
        guard let version = await toolchain.version() else {
            print("[version] none: \(await toolchain.unavailableReason() ?? "unknown")")
            return 1
        }
        print("[version] \(version)")
        var ok = true
        do {
            let build = try await toolchain.build(package: package, target: arguments.value("target"), scratch: scratch)
            print(String(format: "[build] %@ in %.1f s · %d diagnostics", build.succeeded ? "passed" : "FAILED", build.seconds, build.diagnostics.count))
            for diagnostic in build.diagnostics.prefix(12) {
                print("  \(diagnostic.severity.rawValue) \(diagnostic.file):\(diagnostic.line):\(diagnostic.column) \(diagnostic.message)")
            }
            ok = ok && build.succeeded

            if !arguments.has("no-test") {
                let test = try await toolchain.test(package: package, filter: arguments.value("filter"), scratch: scratch)
                print(String(format: "[test] %@ in %.1f s · %d passed · %d failed · %d diagnostics", test.succeeded ? "passed" : "FAILED",
                             test.seconds, test.passed, test.failures.count, test.diagnostics.count))
                for failure in test.failures.prefix(12) { print("  \(failure.test): \(failure.message)") }
                for diagnostic in test.diagnostics.prefix(12) { print("  \(diagnostic.file):\(diagnostic.line) \(diagnostic.message)") }
                ok = ok && test.succeeded
            }

            if !arguments.has("no-install") {
                let started = Date()
                let agent = try await toolchain.install(package: package, shelf: shelf)
                print(String(format: "[install] %@ · words %@ · %.1f s · %@", agent.name, agent.words.joined(separator: ", "),
                             Date().timeIntervalSince(started), agent.executable.path))
                let entries = try await toolchain.describe(agent)
                let described = (try? JSONSerialization.jsonObject(with: entries) as? [[String: Any]])?.compactMap { $0["word"] as? String } ?? []
                print("[describe] \(entries.count) bytes · words \(described.joined(separator: ", "))")
                ok = ok && described == agent.words

                if let word = arguments.value("word") {
                    let input = try readInput(arguments.value("input") ?? "{}")
                    let directory = arguments.value("directory").map(CheckArguments.url) ?? work.appendingPathComponent("call", isDirectory: true)
                    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
                    let outcome = try await toolchain.perform(agent, word: word, input: input, directory: directory)
                    for note in outcome.notes { print("  [note] \(note)") }
                    if let output = outcome.output {
                        print("[perform] \(word) answered · \(output.count) bytes: " + String(decoding: output.prefix(600), as: UTF8.self))
                    } else {
                        print("[perform] \(word) \(outcome.refused ? "refused" : "FAILED"): \(outcome.failure ?? "")")
                    }
                    ok = ok && outcome.succeeded
                }
            }
        } catch {
            print("[toolchain] FAILED: \(error.localizedDescription)")
            return 1
        }
        if arguments.has("keep") { print("[kept] \(work.path)") }
        return ok ? 0 : 1
    }

    /// Inline JSON, or `@path` to a file of it.
    static func readInput(_ said: String) throws -> Data {
        if said.hasPrefix("@") { return try Data(contentsOf: CheckArguments.url(String(said.dropFirst()))) }
        return Data(said.utf8)
    }
}
