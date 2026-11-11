import CraftedCore
import Foundation
import XCTest
@testable import CraftedForge

/// A port's package is a pure function of the run's artefacts: assembled under one name and then another, every
/// identity is stamped anew and every model-written body is placed byte for byte; the template's sample never ships.
final class EngineerAssemblyTests: XCTestCase {
    func files(_ root: URL) -> [String] {
        (FileManager.default.subpaths(atPath: root.path) ?? []).filter { !$0.hasSuffix("/") && !(root.appendingPathComponent($0).hasDirectoryPath) }.sorted()
    }

    func text(_ root: URL, _ path: String) -> String { (try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)) ?? "" }

    func testARenameIsReassemblyWithEveryIdentityStampedAndEveryBodyAsItWas() throws {
        let artefacts = try EngineerHarness.sampleArtefacts(identity: AgentIdentity.derive(display: "Tip Jar"), ported: true)
        let folder = try EngineerPaths.temporaryFolder("assembly")
        let first = AgentIdentity.derive(display: "Tip Jar")
        let second = AgentIdentity.derive(display: "Bill Splitter", word: "splitbills")
        let one = folder.appendingPathComponent(first.package)
        let two = folder.appendingPathComponent(second.package)
        try EngineerAssembly.assemble(template: EngineerPaths.skeleton, identity: first, artefacts: artefacts, into: one)
        try EngineerAssembly.assemble(template: EngineerPaths.skeleton, identity: second, artefacts: artefacts, into: two)

        XCTAssertTrue(text(two, "Sources/BillSplitterAgent/BillSplitterAgent.swift").contains("public static let word = \"splitbills\""))
        XCTAssertTrue(text(two, "Sources/BillSplitterAgent/BillSplitterRecord.swift").contains("let billSplitterRecord: GraniteRoster.Record = { GraniteRoster.record(BillSplitterAgent.self) }"))
        XCTAssertTrue(text(two, "Package.swift").contains("name: \"BillSplitterAgent\""))
        XCTAssertTrue(text(two, "Sources/BillSplitterAgent/CoreExports.swift").contains("@_exported import BillSplitterCore"))
        XCTAssertTrue(text(two, "Sources/BillSplitterCore/CoreResources.swift").contains("BillSplitterAgent_BillSplitterCore.bundle"))
        XCTAssertTrue(text(one, "Sources/TipJarAgent/Surface/Surface.swift").contains("into: [\"tipjar/*\"]"))

        for path in files(two) {
            let body = text(two, path)
            XCTAssertFalse(body.contains("Skeleton") || body.contains("skeleton"), "\(path) still names the template")
        }
        for (template, stampedOne, stampedTwo) in [
            (SkeletonLayout.logic("TipMath"), "Sources/TipJarCore/Logic/TipMath.swift", "Sources/BillSplitterCore/Logic/TipMath.swift"),
            (SkeletonLayout.handler("split"), "Sources/TipJarAgent/Handlers/SplitHandler.swift", "Sources/BillSplitterAgent/Handlers/SplitHandler.swift"),
        ] {
            XCTAssertEqual(text(one, stampedOne), artefacts.slots[template], "a body is placed as it was written")
            XCTAssertEqual(text(two, stampedTwo), artefacts.slots[template])
        }
        XCTAssertEqual(files(one).map { $0.replacingOccurrences(of: "TipJar", with: "X") }.sorted(), files(two).map { $0.replacingOccurrences(of: "BillSplitter", with: "X") }.sorted(),
                       "the same tree under another name")
    }

    func testAPortReplacesTheSampleAndADroppedCommandLeavesNothingBehind() throws {
        var artefacts = try EngineerHarness.sampleArtefacts(identity: AgentIdentity.derive(display: "Tip Jar"), ported: true)
        artefacts.state.dropped = [PortState.Dropped(command: "split", why: "it did not port")]
        let identity = AgentIdentity.derive(display: "Tip Jar")
        let root = try EngineerPaths.temporaryFolder("assembly").appendingPathComponent(identity.package)
        try EngineerAssembly.assemble(template: EngineerPaths.skeleton, identity: identity, artefacts: artefacts, into: root)
        let all = files(root)
        XCTAssertFalse(all.contains { $0.contains("Split") || $0.contains("split.call") }, "\(all.filter { $0.lowercased().contains("split") })")
        XCTAssertTrue(all.contains("Sources/TipJarAgent/Handlers/TipHandler.swift"))
        XCTAssertFalse(text(root, "Sources/TipJarAgent/Surface/Command.swift").contains("case split"))
        XCTAssertFalse(all.contains { $0.hasPrefix("Sample/") || $0 == "template.json" }, "the template's own files never ship")

        // With nothing ported yet, every body is a stub: the tree the port starts from.
        let stubbed = try EngineerHarness.sampleArtefacts(identity: identity, ported: false)
        let start = try EngineerPaths.temporaryFolder("assembly").appendingPathComponent(identity.package)
        try EngineerAssembly.assemble(template: EngineerPaths.skeleton, identity: identity, artefacts: stubbed, into: start)
        XCTAssertTrue(SkeletonCodegen.isStub(text(start, "Sources/TipJarCore/Logic/TipMath.swift")))
        XCTAssertTrue(SkeletonCodegen.isStub(text(start, "Sources/TipJarAgent/Handlers/TipHandler.swift")))
    }

    func testThePipelineAssemblesFromTheRunAloneAndRefusesStubs() async throws {
        let identity = AgentIdentity.derive(display: "Tip Jar")
        var artefacts = try EngineerHarness.sampleArtefacts(identity: identity, ported: true)
        let run = RunFolder(root: try EngineerPaths.temporaryFolder("assembly-run"))
        try run.create()
        try run.write(artefacts.spec, "plan.json")
        try run.write(artefacts.state, "port.json")
        for (path, body) in artefacts.slots { try run.write(SlotBody(path: path, text: body, by: "test"), SlotBody.artefact(path)) }
        for (unit, list) in artefacts.vectors { try run.write(list, "vectors/\(unit).json") }
        for (command, call) in artefacts.calls { try run.write(call, "calls/\(command).json") }
        for (name, carried) in artefacts.carried { try run.write(carried, "carried/\(name).json") }
        let card = InterpretationCard(id: 0, archetype: .whole, name: "Tip Jar", word: "tipjar", summary: "Tips.", commands: [],
                                      leavesOut: [.init(what: "the printed receipt", why: "a file takes its place")])
        try run.write(ProjectRecord(folder: "tipcalc", title: "Tip Calc", licence: "MIT", card: card, files: ["tipcalc.py": "read"]), "project.json")

        let pipeline = EngineerPipeline()
        let templates = TemplateSource(root: EngineerPaths.templates)
        for display in ["Tip Jar", "Gratuity"] {
            let renamed = AgentIdentity.derive(display: display)
            let listing = AgentListing(name: display, word: renamed.word, tagline: "Tips, worked out.")
            let destination = try EngineerPaths.temporaryFolder("assembled").appendingPathComponent(renamed.package)
            let assembled = try await pipeline.assemble(AssemblyRequest(run: run, identity: renamed, listing: listing, templates: templates, destination: destination))
            XCTAssertTrue(assembled.tree.files.contains("PROVENANCE.md"))
            let readme = text(destination, "README.md")
            XCTAssertTrue(readme.hasPrefix("# \(display)\n"))
            XCTAssertTrue(readme.contains("## What was ported and what was not"))
            XCTAssertTrue(readme.contains("$\(renamed.word) tip"))
            XCTAssertTrue(readme.contains("the printed receipt"))
            XCTAssertTrue(text(destination, "NOTICE").contains("Tip Calc"))
            XCTAssertTrue(text(destination, "PROVENANCE.md").contains("Sources/\(renamed.coreTarget)/Logic/TipMath.swift` | ported"))
            XCTAssertEqual(assembled.verification.count, 2)
        }

        artefacts.state.ported = ["TipMath"]
        try run.write(artefacts.state, "port.json")
        let destination = try EngineerPaths.temporaryFolder("assembled").appendingPathComponent(identity.package)
        do {
            _ = try await pipeline.assemble(AssemblyRequest(run: run, identity: identity, listing: AgentListing(name: "Tip Jar", word: "tipjar"),
                                                            templates: templates, destination: destination))
            XCTFail("a package with a stub never ships")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("stubs"), error.localizedDescription)
        }
    }
}
