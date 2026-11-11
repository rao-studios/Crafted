//  WHAT: What a role's pipeline is to the forge: the stages it shows, the generation that turns a folder into
//        artefacts and a verified package, and the assembly that makes a clean package from those artefacts again
//        with whatever name and listing the person settles on.
//  IN:   DesignerPipeline (Designer/), EngineerPipeline (Engineer/).
//  OUT:  Forge (which runs one per generation and assembles on download).
//  PIN:  ASSEMBLY IS PURE. `assemble` reads only the run's artefacts and the request: no model, no question. So a
//        rename, an edited listing, a new icon and a second download are the same call.

import CraftedCore
import Foundation

public protocol RolePipeline: Sendable {
    var role: CraftedRole { get }
    /// Every stage, in order, with its share of the run. Shown up front.
    var stages: [ForgeStage] { get }
    /// Reads the folder, asks the models, writes artefacts under `context.run`, and leaves a package that builds.
    func generate(_ context: ForgeContext) async throws -> PipelineOutcome
    /// A clean package from the run's artefacts, at `request.destination`. Writes README (and NOTICE, PROVENANCE)
    /// itself; the forge writes Assets/listing.json, Assets/icon.png and LICENSE after.
    func assemble(_ request: AssemblyRequest) async throws -> AssembledPackage
}

public struct AssemblyRequest: Sendable {
    public var run: RunFolder
    public var identity: AgentIdentity
    public var listing: AgentListing
    public var templates: TemplateSource
    /// The package folder: Generations/<id>/package/<Package>/.
    public var destination: URL

    public init(run: RunFolder, identity: AgentIdentity, listing: AgentListing, templates: TemplateSource, destination: URL) {
        self.run = run; self.identity = identity; self.listing = listing; self.templates = templates; self.destination = destination
    }
}

public struct AssembledPackage: Sendable {
    public var tree: AssembledTree
    public var verification: [String]
    public var leftOut: [String]
    public var notes: [String]

    public init(tree: AssembledTree, verification: [String] = [], leftOut: [String] = [], notes: [String] = []) {
        self.tree = tree; self.verification = verification; self.leftOut = leftOut; self.notes = notes
    }
}

public struct PipelineOutcome: Codable, Sendable, Equatable {
    /// The listing the pipeline suggests; merged under the person's edits.
    public var listing: AgentListing
    public var summary: String
    /// The interpretation chosen, by title (engineer).
    public var interpretation: String?
    /// The gates the pipeline ran itself while generating (tests, the install, calls over the wire).
    public var gates: [GateResult]
    public var notes: [String]

    public init(listing: AgentListing, summary: String, interpretation: String? = nil, gates: [GateResult] = [], notes: [String] = []) {
        self.listing = listing; self.summary = summary; self.interpretation = interpretation; self.gates = gates; self.notes = notes
    }
}
