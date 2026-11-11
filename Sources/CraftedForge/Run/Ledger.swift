//  WHAT: Everything a model said, on disk, so nothing is asked twice: a run that is cancelled, crashes or is
//        resumed picks up at the first answer it does not have, and a re-run on an updated folder re-asks only for
//        what changed.
//  PIN:  KEYS ARE CONTENT. A key is built from what the answer depends on (a file's sha256, the prompt's version,
//        the model's id), so a changed file or an improved prompt misses, and nothing else does.
//  PIN:  TWO SCOPES. `Ledger` is the run's own (choices, plans, slot bodies); `SharedCache` is shared by every
//        generation (a file's card, a picture's look), under the home's Cache/.

import CraftedCore
import Foundation

public struct Ledger: Sendable {
    public let folder: URL

    public init(folder: URL) { self.folder = folder }

    public func url(_ key: String) -> URL {
        folder.appendingPathComponent(Self.safe(key) + ".json")
    }

    public func get<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = try? Data(contentsOf: url(key)) else { return nil }
        return try? ForgeJSON.decoder.decode(type, from: data)
    }

    public func put<T: Encodable>(_ value: T, _ key: String) throws {
        try AtomicFile.write(try ForgeJSON.encoder.encode(value), to: url(key))
    }

    public func remove(_ key: String) {
        try? FileManager.default.removeItem(at: url(key))
    }

    /// The kept value for `key`, or `make`'s, kept.
    public func value<T: Codable & Sendable>(_ key: String, make: () async throws -> T) async throws -> T {
        if let kept = get(T.self, key) { return kept }
        let made = try await make()
        try put(made, key)
        return made
    }

    /// A file name from any key: path separators and odd characters become underscores; long keys are hashed.
    static func safe(_ key: String) -> String {
        let cleaned = String(key.map { $0.isLetter || $0.isNumber || "-_.".contains($0) ? $0 : "_" })
        return cleaned.count <= 120 ? cleaned : String(cleaned.prefix(60)) + "-" + ContentHash.sha256(key).prefix(16)
    }
}

/// The cache every generation shares: `kind` is cards, looks, measures.
public struct SharedCache: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public func ledger(_ kind: String) -> Ledger { Ledger(folder: root.appendingPathComponent(kind, isDirectory: true)) }
}
