//  WHAT: The forge: a dropped folder in, a Craft agent package out. It starts and resumes runs, and assembles a
//        generation's package (with whatever listing, name and icon the person has saved) for download.
//  IN:   A ForgeModel (live or scripted), an optional ForgeToolchain, the templates, the generation store.
//  OUT:  ForgeService (the app), crafted-check (the terminal).
//  PIN:  DOWNLOAD IS ASSEMBLY. `export` re-assembles from the run's artefacts with the saved listing, re-runs the
//        static gates and the build, then zips: editing the listing later and downloading again is the same path.
//  PIN:  ONE RUN AT A TIME, because one model is resident at a time. The app's ForgeService refuses a second start.

import CraftedCore
import Foundation

public final class Forge: Sendable {
    public let model: any ForgeModel
    public let toolchain: (any ForgeToolchain)?
    public let templates: TemplateSource
    public let store: GenerationStore
    public let pipelines: [any RolePipeline]

    public init(model: any ForgeModel, toolchain: (any ForgeToolchain)?, templates: TemplateSource,
                store: GenerationStore = .shared, pipelines: [any RolePipeline] = Forge.standardPipelines) {
        self.model = model
        self.toolchain = toolchain
        self.templates = templates
        self.store = store
        self.pipelines = pipelines
    }

    public static var standardPipelines: [any RolePipeline] { [DesignerPipeline(), EngineerPipeline()] }

    public func pipeline(_ role: CraftedRole) throws -> any RolePipeline {
        guard let pipeline = pipelines.first(where: { $0.role == role }) else {
            throw ForgeError.notFound("A pipeline for the \(role.title.lowercased()) role")
        }
        return pipeline
    }

    // MARK: Runs

    /// A new generation for `folder`, and its run (not yet started: call `start()` once the consumer is listening).
    public func start(folder: URL, role: CraftedRole, options: ForgeOptions) async throws -> ForgeRun {
        let generation = try await store.create(role: role, source: folder, credit: options.credit)
        return try ForgeRun(id: generation.id, role: role, source: folder, options: options, forge: self, pipeline: pipeline(role))
    }

    /// The run of an interrupted or failed generation, picking up from its ledger.
    public func resume(_ id: String, options: ForgeOptions) async throws -> ForgeRun {
        guard let generation = await store.record(id) else { throw ForgeError.notFound("Generation \(id)") }
        try await store.update(id) { $0.status = .generating; $0.failure = nil }
        return try ForgeRun(id: id, role: generation.role, source: generation.sourceURL, options: options, forge: self,
                            pipeline: pipeline(generation.role))
    }

    /// A finished generation run again over `folder` (the project, updated): unchanged files are not re-read.
    public func update(_ id: String, from folder: URL, options: ForgeOptions) async throws -> ForgeRun {
        guard let generation = await store.record(id) else { throw ForgeError.notFound("Generation \(id)") }
        try await store.update(id) { $0.source = folder.standardizedFileURL.path; $0.status = .generating; $0.failure = nil }
        return try ForgeRun(id: id, role: generation.role, source: folder, options: options, forge: self,
                            pipeline: pipeline(generation.role))
    }

    // MARK: Assembly

    /// The generation's package, assembled with its saved listing and icon into package/<Package>/, and checked.
    public func assemble(_ id: String, options: ForgeOptions = ForgeOptions(), extraGates: [GateResult] = []) async throws -> PackageReport {
        guard let generation = await store.record(id) else { throw ForgeError.notFound("Generation \(id)") }
        let listing = await store.listing(id) ?? AgentListing.placeholder(folderName: generation.sourceName, role: generation.role, credit: options.credit)
        let identity = listing.identity
        let run = RunFolder(root: store.runURL(id))
        let packages = store.packageURL(id)
        try? FileManager.default.removeItem(at: packages)
        let destination = packages.appendingPathComponent(identity.package, isDirectory: true)
        let pipeline = try pipeline(generation.role)
        let assembled = try await pipeline.assemble(AssemblyRequest(run: run, identity: identity, listing: listing,
                                                                     templates: templates, destination: destination))
        try ListingFiles.write(listing: listing, icon: await store.icon(id), identity: identity, role: generation.role, into: destination)

        var gates = extraGates.filter { $0.name != "store" && $0.name != "ship" && $0.name != "build" }
        gates.append(StoreValidator.check(package: destination, identity: identity))
        gates.append(ShipGate.check(package: destination))
        var built = false
        if options.build, let toolchain {
            if await toolchain.version() != nil {
                let result = try await toolchain.build(package: destination, target: nil, scratch: run.buildScratch)
                built = result.succeeded
                gates.append(GateResult(name: "build", passed: result.succeeded,
                                        detail: result.succeeded ? ["swift build passed in \(Int(result.seconds)) s."]
                                            : result.errors.prefix(6).map { "\($0.file):\($0.line): \($0.message)" }))
            } else {
                gates.append(GateResult(name: "build", passed: false, detail: ["No Swift toolchain on this Mac."], skipped: true))
            }
        }
        let files = (try? FileManager.default.subpathsOfDirectory(atPath: destination.path))?
            .filter { ExportFilter.includes($0) && !$0.hasSuffix("/") }.count ?? assembled.tree.files.count
        try await store.update(id) { $0.identity = identity; $0.built = built }
        return PackageReport(package: destination, identity: identity, fileCount: files, gates: gates,
                             verification: assembled.verification, leftOut: assembled.leftOut, notes: assembled.notes, built: built)
    }

    /// Assembles, refuses on a failed gate, and zips to `destination`. Answers the report and the archive.
    public func export(_ id: String, to destination: ExportDestination, options: ForgeOptions = ForgeOptions()) async throws -> (PackageReport, URL) {
        let report = try await assemble(id, options: options)
        if let failed = report.failedGates.first {
            throw ForgeError.gate("The package did not pass the \(failed.name) check: " + failed.detail.prefix(3).joined(separator: " "))
        }
        switch destination {
        case .zip(let url):
            try PackageExport.zip(package: report.package, named: report.identity.package, to: url)
            try await store.update(id) { $0.lastExport = Date(); $0.lastExportPath = url.path }
            return (report, url)
        }
    }
}
