//  WHAT: A run's folder inside its generation: the log, the ledger of everything a model said, the artefacts each
//        stage left, the work trees the port builds in, and the scratch path SwiftPM builds with.
//
//        Generations/<id>/run/
//          events.jsonl  calls.jsonl  ledger/  artefacts/  work/{package, scratch, build}/  shelf/
//
//  PIN:  NEVER INSIDE THE DROPPED FOLDER. A run reads the source and writes only here.

import CraftedCore
import Foundation

public struct RunFolder: Sendable, Equatable {
    public var root: URL

    public init(root: URL) { self.root = root }

    public var events: URL { root.appendingPathComponent("events.jsonl") }
    public var calls: URL { root.appendingPathComponent("calls.jsonl") }
    public var ledger: URL { root.appendingPathComponent("ledger", isDirectory: true) }
    /// What each stage leaves for the next: inventory.json, cards/, usecases.json, style.json …
    public var artefacts: URL { root.appendingPathComponent("artefacts", isDirectory: true) }
    /// The last good package tree a port builds against.
    public var workPackage: URL { root.appendingPathComponent("work/package", isDirectory: true) }
    /// A candidate tree: the last good one plus the one file being tried.
    public var workScratch: URL { root.appendingPathComponent("work/scratch", isDirectory: true) }
    /// SwiftPM's --scratch-path, shared by every build of this run so Granite resolves once.
    public var buildScratch: URL { root.appendingPathComponent("work/build", isDirectory: true) }
    /// The install gate's shelf.
    public var shelf: URL { root.appendingPathComponent("shelf", isDirectory: true) }

    public func artefact(_ name: String) -> URL { artefacts.appendingPathComponent(name) }

    public func create() throws {
        for folder in [root, ledger, artefacts] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    /// Reads an artefact a stage wrote, or nil.
    public func read<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let data = try? Data(contentsOf: artefact(name)) else { return nil }
        return try? ForgeJSON.decoder.decode(type, from: data)
    }

    public func write<T: Encodable>(_ value: T, _ name: String) throws {
        try AtomicFile.write(try ForgeJSON.encoder.encode(value), to: artefact(name))
    }
}

public enum ForgeJSON {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static let line: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
