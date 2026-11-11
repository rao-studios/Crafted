import AtelierKit
import Foundation
import GraniteAgents
import XCTest
@testable import AtelierAgent

/// The package as an app finds it: by its record, with the schema a model is shown, the guide a host prompts with, what
/// it makes, and its designer named in each.
final class AtelierAgentTests: XCTestCase {
    func testTheRecordIsFoundWithNothingListed() throws {
        let agent = try XCTUnwrap(GraniteRoster.discovered().package(AtelierAgent.word), "the record is in this test binary")
        XCTAssertEqual(agent.module, "AtelierAgent")
        XCTAssertEqual(agent.summary, AtelierAgent.summary)
        XCTAssertEqual(agent.lanes, 1, "one WebKit page draws every piece")
    }

    func testTheSchemaIsWhatAModelIsShown() {
        let agent = AnyAgentPackage(AtelierAgent.self)
        XCTAssertEqual(agent.schema, .object([
            .init(name: "brief", schema: .string, required: false),
            .init(name: "format", schema: .choice(PieceFormat.allCases.map(\.rawValue)), required: false),
            .init(name: "content", schema: .string, required: false),
            .init(name: "size", schema: .string, required: false),
            .init(name: "pages", schema: .integer, required: false),
            .init(name: "theme", schema: .choice(["light", "dark"]), required: false),
            .init(name: "spec", schema: .string, required: false),
            .init(name: "output", schema: .string, required: false),
            .init(name: "rounds", schema: .integer, required: false),
            .init(name: "credit", schema: .boolean, required: false),
            .init(name: "directory", schema: .string, required: false),
        ]))
        XCTAssertTrue(agent.takesDirectory)
        XCTAssertEqual(Set(agent.fields.keys), ["brief", "format", "content", "size", "pages", "theme", "spec", "output", "rounds", "credit"],
                       "a note beside every field the model sees")
        XCTAssertEqual(agent.makes.map(\.kind), ["piece"])
    }

    func testTheDesignerIsCreditedInTheSummaryAndTheGuide() {
        let agent = AnyAgentPackage(AtelierAgent.self)
        XCTAssertTrue(agent.summary.contains(DesignerCredit.designer))
        XCTAssertTrue(agent.summary.contains(DesignerCredit.style))
        for word in [DesignerCredit.designer, "format", "brief", "content", "spec", "credit", "colophon"] {
            XCTAssertTrue(agent.guide.contains(word), "the guide says \(word)")
        }
    }

    func testWithoutAModelOrASpecItRefusesSayingWhy() async {
        do {
            _ = try await AnyAgentPackage(AtelierAgent.self).perform(Data(#"{"brief": "a poster for the open studios"}"#.utf8))
            XCTFail("a piece was written with no model")
        } catch {
            XCTAssertEqual(AgentRefusal.of(error)?.kind, .host, "\(error)")
            XCTAssertTrue("\(error)".contains("host's model"), "\(error)")
        }
    }
}
