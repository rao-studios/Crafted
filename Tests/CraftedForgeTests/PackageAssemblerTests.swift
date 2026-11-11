//  WHAT: The assembler stamps a template for a new identity: tokens replaced in text and paths, `verbatim` files and
//        overlays placed byte for byte, generated files stamped, skipped folders left out, `remove` honoured.

@testable import CraftedForge
import CraftedCore
import XCTest

final class PackageAssemblerTests: XCTestCase {
    func testStampsTokensAndPathsAndKeepsVerbatim() throws {
        let template = try StoreFixtures.folder([
            "template.json": """
            {"format": "crafted-template/1", "kind": "engineer",
             "tokens": {"word": "skeletonword", "display": "Skeleton Template", "base": "Skeleton", "lowerBase": "skeleton"},
             "skip": ["Scratch"], "verbatim": ["Sources/SkeletonCore/Logic"]}
            """,
            "Package.swift": #"let package = Package(name: "SkeletonAgent", targets: [.target(name: "SkeletonCore")])"#,
            "Sources/SkeletonAgent/SkeletonAgent.swift": "/// Skeleton Template, called skeletonword.\npublic struct SkeletonAgent { public static let word = \"skeletonword\" }\n",
            "Sources/SkeletonAgent/SkeletonRecord.swift": "let skeletonRecord = GraniteRoster.record(SkeletonAgent.self)\n",
            "Sources/SkeletonCore/Logic/Rules.swift": "// Skeleton stays as the model wrote it.\nlet Skeleton = 1\n",
            "Scratch/notes.txt": "never ships",
            ".build/junk": "never ships",
            "Tests/SkeletonCoreTests/Old.swift": "removed by the plan",
        ])
        defer { try? FileManager.default.removeItem(at: template) }
        let identity = AgentIdentity.derive(display: "Invoice Totals")
        let plan = AssemblyPlan(
            template: template, identity: identity,
            generated: ["Sources/SkeletonCore/Generated/Commands.swift": "enum SkeletonCommand { case total } // skeletonword\n"],
            verbatim: ["Sources/SkeletonCore/Logic/Tax.swift": Data("let SkeletonRate = 0.2 // skeletonword\n".utf8)],
            remove: ["Tests/SkeletonCoreTests"])
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("assembled-\(UUID().uuidString)/\(identity.package)")
        defer { try? FileManager.default.removeItem(at: out.deletingLastPathComponent()) }

        let tree = try PackageAssembler.assemble(plan, into: out)
        func read(_ path: String) throws -> String { try String(contentsOf: out.appendingPathComponent(path), encoding: .utf8) }

        XCTAssertEqual(tree.files, [
            "Package.swift",
            "Sources/InvoiceTotalsAgent/InvoiceTotalsAgent.swift",
            "Sources/InvoiceTotalsAgent/InvoiceTotalsRecord.swift",
            "Sources/InvoiceTotalsCore/Generated/Commands.swift",
            "Sources/InvoiceTotalsCore/Logic/Rules.swift",
            "Sources/InvoiceTotalsCore/Logic/Tax.swift",
        ])
        XCTAssertEqual(try read("Package.swift"), #"let package = Package(name: "InvoiceTotalsAgent", targets: [.target(name: "InvoiceTotalsCore")])"#)
        XCTAssertEqual(try read("Sources/InvoiceTotalsAgent/InvoiceTotalsAgent.swift"),
                       "/// Invoice Totals, called invoicetotals.\npublic struct InvoiceTotalsAgent { public static let word = \"invoicetotals\" }\n")
        XCTAssertEqual(try read("Sources/InvoiceTotalsAgent/InvoiceTotalsRecord.swift"),
                       "let invoiceTotalsRecord = GraniteRoster.record(InvoiceTotalsAgent.self)\n")
        // Generated: stamped. Verbatim (template folder and overlay): byte for byte, only the path stamped.
        XCTAssertEqual(try read("Sources/InvoiceTotalsCore/Generated/Commands.swift"), "enum InvoiceTotalsCommand { case total } // invoicetotals\n")
        XCTAssertEqual(try read("Sources/InvoiceTotalsCore/Logic/Rules.swift"), "// Skeleton stays as the model wrote it.\nlet Skeleton = 1\n")
        XCTAssertEqual(try read("Sources/InvoiceTotalsCore/Logic/Tax.swift"), "let SkeletonRate = 0.2 // skeletonword\n")
        XCTAssertEqual(try PackageAssembler.stampedPath("Sources/SkeletonCore/Logic/Tax.swift", template: template, identity: identity),
                       "Sources/InvoiceTotalsCore/Logic/Tax.swift")

        // Assembling again (a rename) replaces the tree whole.
        let renamed = AgentIdentity.derive(display: "Receipt Sums")
        var again = plan
        again.identity = renamed
        let second = try PackageAssembler.assemble(again, into: out)
        XCTAssertTrue(second.files.contains("Sources/ReceiptSumsAgent/ReceiptSumsAgent.swift"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.appendingPathComponent("Sources/InvoiceTotalsAgent").path))
    }
}
