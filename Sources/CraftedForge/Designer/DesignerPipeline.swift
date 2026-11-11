//  WHAT: A designer's folder into a style agent. Code reads the folder and measures every piece; the vision model looks
//        at a sample and says, by the palette's letters, what it sees; the person decides what may ship and who is
//        credited; the coder model writes the five parts of the style it is left to decide; code reconciles everything
//        by trust order and checks it; the template is stamped with the style; the built agent is tested, installed,
//        and draws the proof sheet itself. See the plan's "Designer pipeline".
//
//        inventory → measure → look (vision) → rights (person) → synthesise (coder) → reconcile → words (coder)
//        → assemble → gates (tests, install, describe, proof)
//
//  IN:   ForgeContext (the folder, the models, the toolchain, the person).
//  OUT:  PipelineOutcome (the listing, the gates); `assemble` makes the package again from the run's artefacts.
//  PIN:  ONE RESIDENT, VISION FIRST. Every look is asked before any coder ask, so a run swaps models once.
//  PIN:  RIGHTS AFTER LOOKS. The mark question is asked once the looks have said which logos are a client's, so a
//        client's logo is never offered as the designer's mark.
//  PIN:  NEVER SHIPS A SAMPLE. The package carries style.json, cleared faces, the designer's confirmed mark and motifs
//        as CSS; no piece of the folder, no photograph, no client's logo.

import CraftedCore
import Foundation

public struct DesignerPipeline: RolePipeline {
    public init() {}

    public var role: CraftedRole { .designer }

    public var stages: [ForgeStage] {
        [
            ForgeStage(id: "inventory", title: "Reading your folder", part: .analysis, weight: 1),
            ForgeStage(id: "measure", title: "Measuring colour, type and space", part: .analysis, weight: 2),
            ForgeStage(id: "look", title: "Looking at your pieces", part: .analysis, weight: 4),
            ForgeStage(id: "rights", title: "Fonts, mark and credit", part: .analysis, weight: 0.5),
            ForgeStage(id: "synthesise", title: "Writing your design system", part: .generation, weight: 4),
            ForgeStage(id: "reconcile", title: "Reconciling and checking the style", part: .generation, weight: 1),
            ForgeStage(id: "words", title: "Naming the agent", part: .generation, weight: 0.5),
            ForgeStage(id: "assemble", title: "Assembling the agent", part: .generation, weight: 1),
            ForgeStage(id: "gates", title: "Testing it and drawing the proof", part: .generation, weight: 5),
        ]
    }

    public func generate(_ context: ForgeContext) async throws -> PipelineOutcome {
        let run = context.run

        context.started("inventory")
        let inventory = try InventoryWalk.walk(source: context.source, artefacts: run.artefacts, looks: context.options.looks) { path, index, total in
            context.progress("inventory", "Reading \(path)", fraction: Double(index) / Double(max(total, 1)), counts: ["filesRead": index, "filesTotal": total])
        }
        try run.write(inventory, "inventory.json")
        for path in inventory.unopenable {
            context.finding(Finding(.skipped, "\((path as NSString).lastPathComponent) cannot be opened here: export it as PDF or PNG and drop the folder again.", path: path))
        }
        for entry in inventory.entries where entry.verdict.hasPrefix("withheld") {
            context.finding(Finding(.withheld, "\(entry.path) was not read: \(entry.verdict.dropFirst(10)).", path: entry.path))
        }
        guard !inventory.distinct.isEmpty else {
            throw ForgeError.stage("Inventory", "the folder holds no piece the forge can open: add PNG, JPEG or PDF exports of your work")
        }
        let duplicates = inventory.pieces.count - inventory.distinct.count
        context.finished("inventory", "\(inventory.distinct.count) pieces\(duplicates > 0 ? " (\(duplicates) near-duplicates set aside)" : ""), "
                         + "\(inventory.fonts.count) font files, \(inventory.declared.count) declared; \(inventory.sampled.count) to look at")

        context.started("measure")
        let measures = try MeasureStage.run(context, inventory: inventory)
        context.finished("measure", "a palette of \(measures.palette.count) colours, \(measures.fonts.count) faces, \(measures.declared.colours.count) declared colours")

        context.started("look")
        let looks = try await DesignLook.run(context, inventory: inventory, measures: measures)
        let sample = inventory.sample.filter { looks[$0.id] != nil }
        let consensus = LookConsensus(looks: sample.map { looks[$0.id]! }, grounds: sample.map { measures.pieces[$0.id]?.ground ?? "unsure" })
        context.finished("look", "\(looks.count) pieces looked at")

        context.started("rights")
        let rights = try await DesignRights.run(context, inventory: inventory, measures: measures, looks: consensus.looks)
        try run.write(rights, "rights.json")
        context.finished("rights", "\(rights.cleared.count) of \(rights.fonts.count) font families ship; credit \(rights.designer)")

        context.started("synthesise")
        let fallbacks = FallbackFaces.load()
        let brief = SynthesisBrief(measures: measures, consensus: consensus, rights: rights, fallbacks: fallbacks)
        let synthesis = try await DesignSynthesis.run(context, brief: brief)
        try run.write(synthesis, "synthesis.json")
        context.finished("synthesise", "colour, type, layout, imagery and voice written")

        context.started("reconcile")
        let folderName = DesignerWords.name(folder: context.source.lastPathComponent)
        var reconciled = StyleReconciler.reconcile(ReconcileInputs(name: folderName, inventory: inventory, measures: measures, consensus: consensus,
                                                                   rights: rights, synthesis: synthesis, fallbacks: fallbacks))
        let problems = StyleValidator.problems(reconciled)
        guard problems.isEmpty else { throw ForgeError.stage("Reconcile", problems.prefix(4).joined(separator: " ")) }
        context.finished("reconcile", "\(reconciled.style.provenance.decisions.count) decisions; \(reconciled.assets.count) files to carry")

        context.started("words")
        let words = try await DesignerWords.ask(context, style: reconciled.style, folder: context.source.lastPathComponent)
        if let name = words?.style.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { reconciled.style.name = name }
        let listing = DesignerWords.listing(style: reconciled.style.name, answer: words,
                                            credit: reconciled.style.credit)
        try writeStyle(reconciled, source: context.source, run: run)
        try run.write(listing, "listing.json")
        context.emit(.listing(listing))
        context.finished("words", listing.name)

        context.started("assemble")
        let identity = listing.identity
        let leftOut = inventory.unopenable.map { "\($0): cannot be opened here; export it as PDF or PNG" }
            + ["the designer's pieces themselves: a style agent carries the style, never the work it was read from"]
            + rights.fonts.filter { $0.decision == "substitute" }.map { "\($0.family): its licence does not let it ship; a face of its class stands in" }
        try run.write(DesignerReport(leftOut: leftOut), "report.json")
        let package = run.workPackage.appendingPathComponent(identity.package, isDirectory: true)
        _ = try await assemble(AssemblyRequest(run: run, identity: identity, listing: listing, templates: context.templates, destination: package))
        try ListingFiles.write(listing: listing, icon: nil, identity: identity, role: .designer, into: package)
        context.finished("assemble", "\(identity.package) at \(package.lastPathComponent)")

        context.started("gates")
        let outcome = try await DesignerGates.run(context, package: package, identity: identity, designer: reconciled.style.credit.designer, leftOut: leftOut)
        try run.write(outcome.report, "report.json")
        for gate in outcome.gates { context.emit(.gate(gate)) }
        let passed = outcome.gates.filter { $0.passed }.count
        context.finished("gates", "\(passed) of \(outcome.gates.count) gates passed" + (outcome.report.proof ? "; proof sheet drawn" : ""))

        return PipelineOutcome(listing: listing,
                               summary: "\(reconciled.style.name), \(reconciled.style.credit.designer)'s design system, as an agent that draws posters, flyers, brochures, cards and slides in it.",
                               gates: outcome.gates, notes: outcome.report.notes + reconciled.style.provenance.decisions.prefix(6))
    }

    public func assemble(_ request: AssemblyRequest) async throws -> AssembledPackage {
        try DesignerAssembly.assemble(request)
    }

    /// The style folder the package carries, under the run's artefacts: style.json and every cleared file, copied
    /// from the folder now, so assembly never reads the folder again.
    func writeStyle(_ reconciled: ReconciledStyle, source: URL, run: RunFolder) throws {
        let folder = run.artefact("style")
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try AtomicFile.write(try ForgeJSON.encoder.encode(reconciled.style), to: folder.appendingPathComponent("style.json"))
        for asset in reconciled.assets {
            let data = try Data(contentsOf: source.appendingPathComponent(asset.from))
            try AtomicFile.write(data, to: folder.appendingPathComponent(asset.to))
        }
        try run.write(reconciled, "reconciled.json")
    }
}
