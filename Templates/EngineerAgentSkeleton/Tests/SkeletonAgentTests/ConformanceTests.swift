//  WHAT: The agent as a host finds and calls it: its record found with nothing listed, its schema as the plan says, a
//        note beside every field, a canonical call per command, the router's refusals, the interpreter with a host
//        model, a hand-off written and read back, and no stub left anywhere in the package.

import Foundation
import GraniteAgents
import XCTest
@testable import SkeletonAgent

final class ConformanceTests: XCTestCase {
    static let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testTheRecordIsFoundWithNothingListed() throws {
        let entry = try XCTUnwrap(GraniteRoster.discovered().package(SkeletonAgent.word), "the record is in this test binary")
        XCTAssertEqual(entry.module, "SkeletonAgent")
        XCTAssertEqual(entry.summary, SkeletonAgent.summary)
        XCTAssertFalse(entry.guide.isEmpty)
    }

    func testTheSchemaIsWhatThePlanSays() {
        let entry = AnyAgentPackage(SkeletonAgent.self)
        XCTAssertEqual(entry.schema, ExpectedSurface.schema)
        XCTAssertTrue(entry.takesDirectory)
        let shown = Set(entry.schema.fields.map(\.name)).subtracting(["directory"])
        XCTAssertEqual(Set(entry.fields.keys), shown, "a note beside every field a model sees")
    }

    func testEveryCommandHasACanonicalCall() throws {
        for command in ExpectedSurface.commands {
            XCTAssertNoThrow(try CallHarness.call(command), "Calls/\(command).call.json")
        }
    }

    func testWhatItMakesCoversWhatItsCommandsPromise() {
        let kinds = Set(SkeletonAgent.makes.map(\.kind))
        for command in ExpectedSurface.commands {
            for expected in Surface.expected(command) {
                XCTAssertTrue(kinds.contains(expected.kind), "\(command) promises a \(expected.kind)")
            }
        }
        XCTAssertTrue(kinds.contains("handoff"))
    }

    func testACallWithNoCommandAndNoModelIsRefusedListingTheCommands() async throws {
        let directory = FileManager.default.temporaryDirectory
        do {
            _ = try await AnyAgentPackage(SkeletonAgent.self).perform(Data("{}".utf8), host: AgentHost(directory: directory.path))
            XCTFail("a call with no command and no model cannot be answered")
        } catch {
            let refusal = try XCTUnwrap(AgentRefusal.of(error))
            XCTAssertEqual(refusal.kind, .call)
            for command in ExpectedSurface.commands { XCTAssertTrue("\(refusal)".contains("`\(command)`"), "\(refusal)") }
        }
    }

    func testTheHostsModelReadsABriefIntoACall() async throws {
        let command = try XCTUnwrap(ExpectedSurface.commands.first)
        let call = try CallHarness.call(command)
        let model = FakeHostModel(answer: try JSONEncoder().encode(call.input))
        let directory = try CallHarness.project(call)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (_, result) = try await CallHarness.perform(["brief": .string("do what the \(command) call does")], in: directory, model: model)
        XCTAssertEqual(result.command, command)
        XCTAssertEqual(model.asks, 1, "one ask of the host's model")
    }

    func testAHandOffIsWrittenAndReadBack() async throws {
        let command = try XCTUnwrap(ExpectedSurface.commands.first)
        let call = try CallHarness.call(command)
        let directory = try CallHarness.project(call)
        defer { try? FileManager.default.removeItem(at: directory) }
        var input = call.input
        input["present"] = .string("context")
        let (_, handed) = try await CallHarness.perform(input, in: directory)
        let path = try XCTUnwrap(handed.paths.first { $0.hasSuffix(Handoff.suffix) }, "\(handed.paths)")
        let handoff = try JSONDecoder().decode(Handoff.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertEqual(handoff.format, Handoff.format)
        XCTAssertEqual(handoff.from.word, SkeletonAgent.word)
        input["present"] = .string("output")
        input["handoff"] = .string(String(path.dropFirst(directory.path.count + 1)))
        let (_, again) = try await CallHarness.perform(input, in: directory)
        XCTAssertEqual(again.command, command)
    }

    func testAnOutputFolderOutsideTheProjectIsRefused() async throws {
        let command = try XCTUnwrap(ExpectedSurface.commands.first)
        let call = try CallHarness.call(command)
        let directory = try CallHarness.project(call)
        defer { try? FileManager.default.removeItem(at: directory) }
        var input = call.input
        input["output"] = .string("../elsewhere")
        do {
            _ = try await CallHarness.perform(input, in: directory)
            XCTFail("an output folder outside the project is refused")
        } catch {
            XCTAssertEqual(AgentRefusal.of(error)?.kind, .call, "\(error)")
        }
    }

    func testNoStubIsLeftInThePackage() throws {
        let sources = Self.package.appendingPathComponent("Sources")
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        for case let url as URL in walker where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.hasPrefix("// crafted:" + "stub"), "\(url.lastPathComponent) is a stub: nothing ships stubbed")
        }
    }
}
