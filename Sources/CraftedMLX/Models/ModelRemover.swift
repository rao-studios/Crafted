//  WHAT: Deletes a model's copy from the shared home and says how much it freed.
//  IN:   Settings › Models' Remove, after a confirmation that says Craft uses the same copy.
//  OUT:  ModelService's Remove reducer.
//  PIN:  ONLY FROM THIS HOME'S OWN ROOTS. A copy found through the Rao stack's folder while AII_HOME points elsewhere
//        is not Crafted's to delete; the remover refuses it rather than reach outside.
//  PIN:  THE COPY IS SHARED. Removing it removes Craft's copy too: the page's dialog says so before anything is deleted.

import CraftedCore
import Foundation

public enum ModelRemover {
    public enum Failure: Error, LocalizedError, Equatable {
        case notHere(String)
        case outside(String)

        public var errorDescription: String? {
            switch self {
            case .notHere(let name): return "\(name) is not on this Mac."
            case .outside(let path): return "\(path) is outside Crafted's model folder; remove it where it was put."
            }
        }
    }

    /// Deletes `spec`'s folder. Answers the bytes freed.
    @discardableResult
    public static func remove(_ spec: ModelSpec, home: ModelHome = .standard) throws -> Int64 {
        let fm = FileManager.default
        var candidates = home.ownRoots.map { $0.appendingPathComponent("models").appendingPathComponent(spec.id) }
        candidates.append(home.folder(spec))
        var freed: Int64 = 0
        var removed = false
        var seen = Swift.Set<String>()
        for folder in candidates where seen.insert(folder.standardizedFileURL.path).inserted {
            guard fm.fileExists(atPath: folder.path) else { continue }
            freed += ModelLocator.bytesOnDisk(folder)
            try fm.removeItem(at: folder)
            removed = true
        }
        if !removed {
            if let located = ModelLocator.locate(spec, home: home) { throw Failure.outside(located.path.path) }
            throw Failure.notHere(spec.name)
        }
        return freed
    }
}
