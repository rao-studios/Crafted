//  WHAT: All a handler may touch: files of the project (read only, inside its folder), the carried resources, what an
//        upstream agent handed on, the host's model, one fixed `now` and a seed for the call, and a line of progress.
//  IN:   The router, once per call.
//  OUT:  Every handler (`run(_:_:)`).
//  PIN:  CONFINED. A path is read against the project folder and refused when it leaves it, by `..` or by a link; a
//        handler cannot write, list outside, run a process or reach a network through the kit, and has nothing else.
//  PIN:  ONE CLOCK, ONE SEED. `now` is read once per call and `seed` is the call's (or derived from its input), so a
//        handler that is given the same call makes the same products.

import Foundation
import GraniteAgents

public struct CommandKit: Sendable {
    /// The command being run.
    public let command: String
    /// The project folder: every path a handler reads is inside it.
    public let directory: URL
    /// The call's one moment.
    public let now: Date
    /// The call's seed: given in the call, else derived from its input.
    public let seed: Int
    /// What an upstream agent handed on, when the call names a hand-off file.
    public let upstream: Handoff?

    let host: AgentHost
    private let line: @Sendable (String) -> Void

    init(command: String, input: AgentInput, host: AgentHost, note: @escaping @Sendable (String) -> Void, now: Date = Date()) throws {
        self.command = command
        let base = input.directory ?? host.directory ?? FileManager.default.currentDirectoryPath
        directory = URL(fileURLWithPath: (base as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
        self.now = now
        seed = input.seed ?? Self.seed(of: input)
        self.host = host
        line = note
        if let handoff = input.handoff {
            upstream = try HandoffReader.read(Self.confined(handoff, in: directory))
        } else {
            upstream = nil
        }
    }

    // MARK: Files

    /// `path` (relative to the project, or absolute inside it) as a file URL, refused when it leaves the folder.
    public func url(_ path: String) throws -> URL { try Self.confined(path, in: directory) }

    public func exists(_ path: String) -> Bool {
        (try? url(path)).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    public func read(_ path: String) throws -> Data {
        let file = try url(path)
        do {
            return try Data(contentsOf: file)
        } catch {
            throw Refusals.unreadable(path, FileManager.default.fileExists(atPath: file.path) ? "it would not open" : "there is no such file")
        }
    }

    public func text(_ path: String) throws -> String {
        let data = try read(path)
        guard let text = String(data: data, encoding: .utf8) else { throw Refusals.unreadable(path, "it is not UTF-8 text") }
        return text
    }

    /// The names in a folder of the project, sorted; hidden names left out.
    public func list(_ folder: String) throws -> [String] {
        let place = try url(folder)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: place.path)) ?? []
        return names.filter { !$0.hasPrefix(".") }.sorted()
    }

    // MARK: Resources

    public func resource(_ name: String) throws -> Data { try CoreResources.data(name) }

    public func resourceText(_ name: String) throws -> String { try CoreResources.text(name) }

    // MARK: The host

    /// The host's model, asked for a `T`; refused as `call` when the host has none, `model` when it answers nothing usable.
    public func ask<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, maxTokens: Int = 1200) async throws -> T {
        guard let model = host.model else {
            throw AgentRefusal(.call, "`\(command)` needs the host's model for this, and this host offers none: run it from Craft with a model loaded.")
        }
        do {
            return try await model.object(type, system: system, user: user, maxTokens: maxTokens, seconds: 180)
        } catch {
            throw AgentRefusal(.model, "The host's model gave nothing usable for `\(command)`: \(error).")
        }
    }

    /// The host's model, asked for text.
    public func askText(system: String, user: String, maxTokens: Int = 1200) async throws -> String {
        guard let model = host.model else {
            throw AgentRefusal(.call, "`\(command)` needs the host's model for this, and this host offers none: run it from Craft with a model loaded.")
        }
        do {
            return try await model.text(system: system, user: user, maxTokens: maxTokens, seconds: 180)
        } catch {
            throw AgentRefusal(.model, "The host's model gave nothing usable for `\(command)`: \(error).")
        }
    }

    /// A line of progress the host shows.
    public func note(_ text: String) { line(text) }

    /// A generator seeded by the call.
    public func random() -> SeededGenerator { SeededGenerator(seed: seed) }

    // MARK: Rules

    static func confined(_ path: String, in directory: URL) throws -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        let candidate = expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded) : directory.appendingPathComponent(expanded)
        let base = directory.standardizedFileURL.resolvingSymlinksInPath().path
        let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath().path
        guard resolved == base || resolved.hasPrefix(base.hasSuffix("/") ? base : base + "/") else { throw Refusals.outside(path) }
        return candidate.standardizedFileURL
    }

    /// FNV-1a over the input's JSON, keys sorted: the same call, the same seed.
    static func seed(of input: AgentInput) -> Int {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var copy = input
        copy.directory = nil
        let data = (try? encoder.encode(copy)) ?? Data()
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in data { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return Int(truncatingIfNeeded: hash & 0x7FFF_FFFF)
    }
}
