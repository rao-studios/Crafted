//  WHAT: The runtime's composition root: a main-actor object holding a relay to every runtime service for the life of
//        the process, and the boot that wires their residents: the Forge (with its model, toolchain and templates) and
//        the generation store.
//  IN:   The app root's launch (CraftedAppRoot), the self-test.
//  OUT:  PreferencesService, ModelService, LibraryService, ForgeService.
//  PIN:  A relay is live from its init, so this one object holding a relay to every service is the executor of every
//        runtime reducer. The logger is quieted before the first relay: a relay restores its store as it is made.
//  PIN:  THE MODEL IS CHOSEN HERE, ONCE. `CRAFTED_MODELS=scripted` gives the forge ScriptedModel over the fixtures'
//        scripts (Fixtures/scripts, or CRAFTED_SCRIPTS); anything else gives LiveForgeModel over MLXModelRuntime. Not a
//        mock mode: both are ForgeModels and the pipeline cannot tell them apart.

import CraftedCore
import CraftedForge
import CraftedToolchain
import Foundation
import Granite

@MainActor
public final class CraftedRuntimeRoot {
    public static let shared: CraftedRuntimeRoot = {
        GraniteLogger.currentLevel = .error
        return CraftedRuntimeRoot()
    }()

    @Relay(.silence) public var preferences: PreferencesService
    @Relay(.silence) public var models: ModelService
    @Relay(.silence) public var library: LibraryService
    @Relay(.silence) public var forge: ForgeService

    public private(set) var isBooted = false
    /// Which model the forge was given.
    public private(set) var modelChoice: ModelChoice = .live

    private init() {}

    /// The residents every reducer works through. Before any send; a second call does nothing.
    public func boot() {
        guard !isBooted else { return }
        let (model, choice) = Self.forgeModel()
        modelChoice = choice
        library.connect(store: .shared)
        let templates = TemplateSource.locate() ?? TemplateSource(root: Self.fallbackTemplates)
        forge.connect(Forge(model: model, toolchain: SwiftToolchain(), templates: templates, store: .shared))
        isBooted = true
    }

    /// The model the forge runs on, and what to call it.
    public static func forgeModel(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> (any ForgeModel, ModelChoice) {
        guard environment["CRAFTED_MODELS"]?.lowercased() == "scripted" else { return (LiveForgeModel(), .live) }
        if let scripts = ScriptedModel.locateScripts() {
            return (ScriptedModel(scripts: scripts), .scripted(scripts.path))
        }
        // No scripts found: every ask fails with the scripted model's own "no answer" error, which the run shows.
        let missing = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Fixtures/scripts")
        return (ScriptedModel(scripts: missing), .scripted(nil))
    }

    /// Where templates would be when none was found: the repository's Templates/ beside the working directory.
    static var fallbackTemplates: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Templates", isDirectory: true)
    }
}

public enum ModelChoice: Equatable, Sendable {
    case live
    /// The scripts folder, or nil when none was found.
    case scripted(String?)

    public var title: String {
        switch self {
        case .live: return "On-device models"
        case .scripted(let path?): return "Scripted models (\((path as NSString).abbreviatingWithTildeInPath))"
        case .scripted(nil): return "Scripted models (no scripts found)"
        }
    }

    public var isScripted: Bool { if case .scripted = self { return true }; return false }
}
