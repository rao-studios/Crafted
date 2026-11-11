//  WHAT: Whether a model is on this Mac, and where: a complete copy in the shared home, read from disk every time.
//  IN:   ModelHome's lookup roots; Frigate's `HubDownloader.materializedSnapshot` (config, every weight shard named
//        by the index, the tokenizer).
//  OUT:  ModelService (the cards, the onboarding gate), the runtime's load.
//  PIN:  ANY COMMIT. A complete copy is accepted whatever commit it was fetched at, so the copy Craft downloaded is
//        used where it sits; the card says when it is not the pinned one.
//  PIN:  A FOLDER WITH `.incomplete` MARKERS IS NOT A MODEL. The Hub writes `<file>.<etag>.incomplete` under the
//        snapshot's .cache while a file downloads and leaves it when a download stops; such a copy is mid-download.

import CraftedCore
import Foundation
import FrigateBridge

/// A model found on disk.
public struct LocatedModel: Sendable, Equatable {
    public var kind: ModelKind
    public var path: URL
    /// The commit its config.json was fetched at, when the Hub recorded one.
    public var commit: String?
    public var bytes: Int64

    public init(kind: ModelKind, path: URL, commit: String?, bytes: Int64) {
        self.kind = kind; self.path = path; self.commit = commit; self.bytes = bytes
    }

    /// Fetched at the commit Crafted pins (a copy with no record of its commit is not counted as pinned).
    public func matchesPin(_ spec: ModelSpec) -> Bool { commit?.lowercased() == spec.revision.lowercased() }
}

public enum ModelLocator {
    /// A complete copy of `spec`, at any commit; nil when there is none or it is still downloading.
    public static func locate(_ spec: ModelSpec, home: ModelHome = .standard) -> LocatedModel? {
        guard let folder = HubDownloader.materializedSnapshot(id: spec.id, revision: nil,
                                                              matching: ModelDownloader.patterns, roots: home.lookupRoots)
        else { return nil }
        guard !hasIncompleteMarkers(folder) else { return nil }
        return LocatedModel(kind: spec.kind, path: folder, commit: HubDownloader.snapshotCommit(folder),
                            bytes: bytesOnDisk(folder))
    }

    /// Whether a download of this folder stopped part-way (or is going on).
    public static func hasIncompleteMarkers(_ folder: URL) -> Bool {
        let download = folder.appendingPathComponent(".cache/huggingface/download", isDirectory: true)
        guard let walker = FileManager.default.enumerator(at: download, includingPropertiesForKeys: nil) else { return false }
        for case let url as URL in walker where url.pathExtension == "incomplete" { return true }
        return false
    }

    /// Every regular file under `folder`, the Hub's bookkeeping included.
    public static func bytesOnDisk(_ folder: URL) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let walker = FileManager.default.enumerator(at: folder.resolvingSymlinksInPath(), includingPropertiesForKeys: keys)
        else { return 0 }
        var total: Int64 = 0
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: Swift.Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    /// What a download of `spec` still needs: its size less what already sits in its folder (finished files and the
    /// part of a stopped one), never below zero.
    public static func remainingBytes(_ spec: ModelSpec, home: ModelHome = .standard) -> Int64 {
        if locate(spec, home: home) != nil { return 0 }
        let present = bytesOnDisk(home.folder(spec))
        return max(0, spec.downloadBytes - present)
    }
}
