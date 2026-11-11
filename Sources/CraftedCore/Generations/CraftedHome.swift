//  WHAT: Where Crafted keeps what it makes: one folder per generation, the content-addressed cache shared across
//        generations, and a scratch shelf for the install gate.
//  OUT:  GenerationStore, the forge's run folders, the model-free tests (a temporary home).
//  PIN:  THE APP'S OWN FOLDER, not ~/Documents: ~/Library/Application Support/nyc.rao.crafted. `CRAFTED_HOME`
//        moves it (tests, a clean first launch).

import Foundation

public struct CraftedHome: Sendable, Equatable {
    public var root: URL

    public init(root: URL) { self.root = root }

    public static var standard: CraftedHome {
        if let override = ProcessInfo.processInfo.environment["CRAFTED_HOME"], !override.isEmpty {
            return CraftedHome(root: URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true))
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return CraftedHome(root: support.appendingPathComponent("nyc.rao.crafted", isDirectory: true))
    }

    /// One folder per generation: generation.json, listing.json, icon.png, run/, package/.
    public var generations: URL { root.appendingPathComponent("Generations", isDirectory: true) }
    /// Cards, looks and measures, keyed by content, shared by every generation.
    public var cache: URL { root.appendingPathComponent("Cache", isDirectory: true) }
    /// Where the install gate puts a runner it builds, one folder per check, removed after.
    public var shelf: URL { root.appendingPathComponent("Shelf", isDirectory: true) }

    public func generation(_ id: String) -> URL { generations.appendingPathComponent(id, isDirectory: true) }
}
