//  WHAT: The install gate on a fake toolchain (no build, no process): the word --describe says must be the
//        listing's, each call must answer or refuse as expected, no toolchain skips; and the capability scan finds
//        network, process and import use in a body, by line, and not in comments or strings.

@testable import CraftedForge
import CraftedCore
import XCTest

final class InstallGateTests: XCTestCase {
    struct FakeToolchain: ForgeToolchain {
        var present = true
        var word = "invoicetotals"
        var answers: [String: CallOutcome] = [:]

        func version() async -> String? { present ? "Swift 6.4.2" : nil }
        func build(package: URL, target: String?, scratch: URL) async throws -> BuildResult { BuildResult(succeeded: true) }
        func test(package: URL, filter: String?, scratch: URL) async throws -> TestResult { TestResult(succeeded: true) }
        func install(package: URL, shelf: URL) async throws -> InstalledAgent {
            let folder = shelf.appendingPathComponent("InvoiceTotalsAgent")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return InstalledAgent(name: "InvoiceTotalsAgent", folder: folder, executable: folder.appendingPathComponent("agent"), words: [word])
        }
        func describe(_ agent: InstalledAgent) async throws -> Data { Data(#"[{"kind":"package","word":"\#(word)"}]"#.utf8) }
        func perform(_ agent: InstalledAgent, word: String, input: Data, directory: URL) async throws -> CallOutcome {
            answers[String(decoding: input, as: UTF8.self)] ?? CallOutcome(failure: "no")
        }
    }

    let identity = AgentIdentity.derive(display: "Invoice Totals")
    let temp = FileManager.default.temporaryDirectory

    func testPassesAndCleansTheShelf() async throws {
        let shelf = temp.appendingPathComponent("shelf-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: shelf) }
        let toolchain = FakeToolchain(answers: ["{\"command\":\"total\"}": CallOutcome(output: Data("{}".utf8)),
                                                "{\"brief\":\"total it\"}": CallOutcome(failure: "needs a model", refused: true)])
        let gate = try await InstallGate.check(toolchain: toolchain, package: temp, shelf: shelf, identity: identity, calls: [
            .init(name: "total", input: Data(#"{"command":"total"}"#.utf8)),
            .init(name: "words without a model", input: Data(#"{"brief":"total it"}"#.utf8), expectRefusal: true),
        ], directory: temp.appendingPathComponent("calls-\(UUID().uuidString)"))
        XCTAssertTrue(gate.passed, gate.detail.joined(separator: "\n"))
        XCTAssertEqual(gate.detail.count, 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: shelf.appendingPathComponent("InvoiceTotalsAgent").path))
    }

    func testFailsOnTheWrongWordAndAFailedCallAndSkipsWithoutToolchain() async throws {
        let shelf = temp.appendingPathComponent("shelf-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: shelf) }
        let gate = try await InstallGate.check(toolchain: FakeToolchain(word: "other"), package: temp, shelf: shelf, identity: identity,
                                               calls: [.init(name: "total", input: Data("{}".utf8))], directory: shelf)
        XCTAssertFalse(gate.passed)
        XCTAssertTrue(gate.detail[0].contains("not $invoicetotals"), gate.detail[0])
        XCTAssertTrue(gate.detail[1].contains("total failed"), gate.detail[1])

        let skipped = try await InstallGate.check(toolchain: FakeToolchain(present: false), package: temp, shelf: shelf,
                                                  identity: identity, calls: [], directory: shelf)
        XCTAssertTrue(skipped.skipped)
    }

    func testCapabilityScan() {
        let body = """
        import Foundation
        import Network
        /* a block comment
           that says URLSession */
        // Process() in a comment is fine
        let message = "call URLSession later"
        func fetch() { _ = URLSession.shared }
        func run() { let p = Process(); _ = p }
        """
        let hits = CapabilityScan.hits(in: body, path: "Sources/XCore/Logic/Fetch.swift", allowedImports: CapabilityScan.coreImports)
        XCTAssertEqual(hits.map(\.line), [2, 2, 7, 8])
        XCTAssertEqual(Set(hits.map(\.what)), ["the network", "a process", "an import of Network, which this target may not use"])
        XCTAssertTrue(CapabilityScan.hits(in: "import Foundation\nlet x = 1\n", path: nil, allowedImports: CapabilityScan.coreImports).isEmpty)
        XCTAssertTrue(CapabilityScan.problems(in: body, path: "F.swift").first?.hasPrefix("F.swift:2 uses the network") == true)
    }
}
