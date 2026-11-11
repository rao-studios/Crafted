import CraftedCore
@testable import CraftedForge
import Foundation
import XCTest

/// Both design fixtures through the real pipeline on their scripts, with no toolchain (so no build, install or proof:
/// those gates are skipped and say why): a style agent package, its style reconciled and carried, nothing of the
/// designer's work in it, and a rename that is re-assembly.
final class DesignerPipelineTests: XCTestCase {
    private func generate(_ fixture: String, credit: String = "Test Designer") async throws -> (Forge, String, PackageReport, [ForgeEvent]) {
        let home = try DesignerSupport.scratch("designer-home")
        let forge = Forge(model: ScriptedModel(scripts: DesignerSupport.scripts), toolchain: nil, templates: DesignerSupport.templates,
                          store: GenerationStore(home: CraftedHome(root: home)), pipelines: [DesignerPipeline()])
        let options = ForgeOptions(credit: credit, autoDecide: true, looks: 24, build: false, install: false)
        try DesignerSupport.requireFixtures()
        let run = try await forge.start(folder: DesignerSupport.fixture(fixture), role: .designer, options: options)
        let collected = Task { () -> [ForgeEvent] in
            var events: [ForgeEvent] = []
            for await event in run.events { events.append(event) }
            return events
        }
        await run.start()
        await run.wait()
        let events = await collected.value
        if case .failed(let failure)? = events.last { XCTFail("the run failed: \(failure.reason)") }
        guard case .completed(let report)? = events.last else { throw ForgeError.stage("test", "the run did not complete: \(String(describing: events.last))") }
        return (forge, run.id, report, events)
    }

    private func text(_ package: URL, _ path: String) throws -> String { try String(contentsOf: package.appendingPathComponent(path), encoding: .utf8) }

    func testSwissMonoBecomesAStyleAgentAndARenameIsReassembly() async throws {
        let (forge, id, report, events) = try await generate("swiss-mono")
        let package = report.package
        XCTAssertEqual(report.identity.display, "Swiss Mono by Test Designer")
        XCTAssertEqual(package.lastPathComponent, "SwissMonoByTestDesignerAgent")
        XCTAssertEqual(report.failedGates.map(\.name), [], "\(report.gates)")
        XCTAssertTrue(report.gates.contains { $0.name == "proof" && $0.skipped }, "no toolchain: the proof is skipped, not failed")
        // The style, as the kit reads it.
        let kit = package.appendingPathComponent("Sources/SwissMonoByTestDesignerKit/Resources/Style")
        let style = try ForgeJSON.decoder.decode(DesignerStyle.self, from: Data(contentsOf: kit.appendingPathComponent("style.json")))
        XCTAssertEqual(style.name, "Swiss Mono")
        XCTAssertEqual(style.credit.designer, "Test Designer")
        XCTAssertEqual(style.colour.hex("background", "light"), "#F7F7F2")
        XCTAssertEqual(style.colour.hex("accent", "light"), "#E30613", "the declared red, exactly")
        XCTAssertEqual(style.type.roles["heading"]?.family, "Playfair Display")
        XCTAssertEqual(style.type.roles["heading"]?.source, "bundled")
        XCTAssertEqual(style.type.roles["display"]?.family, "Helvetica Neue")
        XCTAssertEqual(style.mark?.asset, "Marks/mark.svg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: kit.appendingPathComponent("Fonts/PlayfairDisplay-Italic-VariableFont_wght.ttf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: kit.appendingPathComponent("Fonts/OFL.txt").path), "the face ships with its licence")
        XCTAssertTrue(style.provenance.decisions.contains { $0.contains("background A (declared)") }, "tokens.css named the paper: \(style.provenance.decisions)")
        XCTAssertEqual(StyleValidator.problems(ReconciledStyle(style: style, assets: [])).filter { !$0.contains("carries") }, [])
        // Credit everywhere the package can say it.
        XCTAssertTrue(try text(package, "README.md").contains("**Design by Test Designer.**"))
        XCTAssertTrue(try text(package, "NOTICE").contains("CC BY 4.0"))
        XCTAssertTrue(try text(package, "Sources/SwissMonoByTestDesignerAgent/Values/DesignerCredit.swift").contains(#"static let designer = "Test Designer""#))
        let listing = try JSONSerialization.jsonObject(with: Data(contentsOf: package.appendingPathComponent("Assets/listing.json"))) as? [String: Any]
        XCTAssertEqual((listing?["credit"] as? [String: Any])?["designer"] as? String, "Test Designer")
        XCTAssertEqual(listing?["category"] as? String, "graphics")
        XCTAssertFalse(events.contains { if case .finding(let f) = $0 { return f.kind == .fallback }; return false },
                       "every synthesis part held after its repairs (a hex in a look, an invented voice sample)")
        // Nothing of the designer's work ships.
        let files = try FileManager.default.subpathsOfDirectory(atPath: package.path)
        XCTAssertFalse(files.contains { $0.hasSuffix("poster-form-follows-grid.png") || $0.hasSuffix("tokens.css") || $0.hasSuffix("about.txt") }, "\(files)")
        XCTAssertFalse(files.contains { $0.contains("Atelier") }, "every path is stamped")

        // Rename: a new identity over the same artefacts.
        let styleBefore = try Data(contentsOf: kit.appendingPathComponent("style.json"))
        let store = forge.store
        let current = await store.listing(id)
        var renamed = try XCTUnwrap(current)
        renamed.name = "Neue Grid"
        renamed.word = "neuegrid"
        renamed.edited.formUnion([.name, .word])
        try await store.saveListing(renamed, id)
        let again = try await forge.assemble(id, options: ForgeOptions(build: false, install: false))
        XCTAssertEqual(again.package.lastPathComponent, "NeueGridAgent")
        let restamped = again.package
        XCTAssertEqual(try Data(contentsOf: restamped.appendingPathComponent("Sources/NeueGridKit/Resources/Style/style.json")), styleBefore,
                       "the style is placed byte for byte, whatever the agent is called")
        let agent = try text(restamped, "Sources/NeueGridAgent/NeueGridAgent.swift")
        XCTAssertTrue(agent.contains(#"public static let word = "neuegrid""#))
        XCTAssertTrue(agent.contains("public struct NeueGridAgent: GraniteAgentPackage"))
        XCTAssertTrue(try text(restamped, "Sources/NeueGridAgent/NeueGridRecord.swift").contains("let neueGridRecord"))
        XCTAssertTrue(try text(restamped, "Package.swift").contains(#"name: "NeueGridAgent""#))
        XCTAssertTrue(try text(restamped, "README.md").contains("$neuegrid"))
        XCTAssertTrue(try text(restamped, "Sources/NeueGridAgent/Values/DesignerCredit.swift").contains(#""Test Designer""#), "the credit is placed, not stamped")
        let restampedFiles = try FileManager.default.subpathsOfDirectory(atPath: restamped.path)
        for file in restampedFiles where file.hasSuffix(".swift") || file.hasSuffix(".md") || file == "Package.swift" {
            XCTAssertFalse(try text(restamped, file).contains("Atelier") || text(restamped, file).contains("atelierword"), "\(file) still names the template")
        }
    }

    func testVelvetNightStandsInForAFaceItCannotShipAndCarriesNoClientLogo() async throws {
        let (_, _, report, events) = try await generate("velvet-night", credit: "Teo Brandt")
        XCTAssertEqual(report.failedGates.map(\.name), [], "\(report.gates)")
        let kit = report.package.appendingPathComponent("Sources/\(report.identity.kitTarget)/Resources/Style")
        let style = try ForgeJSON.decoder.decode(DesignerStyle.self, from: Data(contentsOf: kit.appendingPathComponent("style.json")))
        XCTAssertEqual(style.name, "Velvet Night")
        XCTAssertEqual(style.colour.hex("background", "dark"), "#1A0F1F", "the declared plum")
        XCTAssertEqual(style.colour.hex("ink", "dark"), "#F3E9DA", "the declared cream, over the measured gold")
        XCTAssertEqual(style.type.roles["display"]?.family, "Didot", "Velour Grotesk is not in the folder: a didone stands in")
        XCTAssertEqual(style.type.roles["display"]?.source, "fallback")
        XCTAssertTrue(style.provenance.decisions.contains { $0.hasPrefix("accent C #C9A45C on light background") }, "the gold on cream was darkened to read: \(style.provenance.decisions)")
        XCTAssertTrue(style.provenance.decisions.contains { $0.contains("Velour Grotesk is declared but not in the folder") }, "\(style.provenance.decisions)")
        XCTAssertTrue(style.provenance.decisions.contains { $0.contains("ACME CORP") }, "the client's logo is noted, not carried")
        XCTAssertNil(style.mark)
        XCTAssertTrue(style.motifs.allSatisfy { !($0.css ?? "").contains("url(") }, "the motif with a URL was refused and repaired")
        XCTAssertEqual(style.motifs.map(\.id), ["rose-frame", "gold-rule"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: kit.appendingPathComponent("Fonts").path), "no face ships")
        XCTAssertTrue(events.contains { if case .finding(let f) = $0 { return f.text.contains("moodboard.sketch") && f.text.contains("export it as PDF or PNG") }; return false })
        XCTAssertTrue(report.leftOut.contains { $0.contains("moodboard.sketch") })
        let notice = try String(contentsOf: report.package.appendingPathComponent("NOTICE"), encoding: .utf8)
        XCTAssertTrue(notice.contains("Velour Grotesk"), notice)
    }
}
