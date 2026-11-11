//  WHAT: The ask path on the scripted model: `once` answers are spent, `match` picks among answers, a missing answer
//        names its purpose; a structured ask repairs a bad first reply, repairs an answer its check refuses, and
//        fails typed after its repairs; every call is logged.

@testable import CraftedForge
import CraftedCore
import XCTest

final class AskingTests: XCTestCase {
    struct Thing: Codable, Sendable, Equatable {
        var name: String
        var count: Int
    }

    func answer(_ purpose: String, match: String? = nil, text: String? = nil, json: JSONValue? = nil, once: Bool? = nil) -> ScriptedModel.Answer {
        ScriptedModel.Answer(purpose: purpose, match: match, text: text, json: json, once: once)
    }

    func prompt(_ purpose: String, _ user: String = "go") -> ModelPrompt { ModelPrompt(purpose: purpose, system: "sys", user: user) }

    func testOnceAnswersAreSpentAndMatchPicks() async throws {
        let model = ScriptedModel(scripts: FileManager.default.temporaryDirectory)
        await model.load(ScriptedModel.Script(format: "crafted-script/1", answers: [
            answer("t.text", text: "first", once: true),
            answer("t.text", match: "tax.py", text: "about tax"),
            answer("t.text", text: "after"),
        ]))
        let first = try await model.text(.coder, prompt("t.text"), .card).text
        let second = try await model.text(.coder, prompt("t.text"), .card).text
        let matched = try await model.text(.coder, prompt("t.text", "read tax.py"), .card).text
        XCTAssertEqual([first, second, matched], ["first", "after", "about tax"])
        do {
            _ = try await model.text(.coder, prompt("t.other"), .card)
            XCTFail("an unscripted purpose answers nothing")
        } catch let error as ForgeError {
            guard case .noScriptedAnswer(let purpose, _) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(purpose, "t.other")
        }
    }

    func testBindReadsTheFixturesScript() async throws {
        let scripts = try StoreFixtures.folder(["demo.json": #"{"format": "crafted-script/1", "answers": [{"purpose": "*", "text": "hi"}]}"#])
        defer { try? FileManager.default.removeItem(at: scripts) }
        let model = ScriptedModel(scripts: scripts)
        await model.bind(source: URL(fileURLWithPath: "/somewhere/demo"))
        let reply = try await model.text(.vision, prompt("any"), .card)
        XCTAssertEqual(reply.text, "hi")
        let resident = await model.resident()
        XCTAssertEqual(resident, .vision)
    }

    func testStructuredAskRepairsABadFirstReply() async throws {
        let model = ScriptedModel(scripts: FileManager.default.temporaryDirectory)
        await model.load(ScriptedModel.Script(format: nil, answers: [
            answer("t.obj", text: "Sure! Here it is: {name: oops", once: true),
            answer("t.obj", match: "had these problems", text: "```json\n{\"name\": \"ok\", \"count\": 2}\n```"),
        ]))
        let calls = FileManager.default.temporaryDirectory.appendingPathComponent("calls-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: calls) }
        let ask = StructuredAsk(model: model, calls: calls)
        let thing = try await ask.object(.coder, prompt("t.obj"), as: Thing.self, budget: .card)
        XCTAssertEqual(thing, Thing(name: "ok", count: 2))
        let lines = try String(contentsOf: calls, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("refused"))
        XCTAssertTrue(lines[1].contains("\"outcome\":\"ok\""))
    }

    func testStructuredAskRepairsWhatTheCheckRefusesThenFailsTyped() async throws {
        let model = ScriptedModel(scripts: FileManager.default.temporaryDirectory)
        await model.load(ScriptedModel.Script(format: nil, answers: [
            answer("t.obj", json: ["name": "zero", "count": 0], once: true),
            answer("t.obj", json: ["name": "two", "count": 2], once: true),
            answer("t.obj", json: ["name": "never", "count": -1]),
        ]))
        let ask = StructuredAsk(model: model, calls: nil)
        let checked = try await ask.object(.coder, prompt("t.obj"), as: Thing.self, budget: .card) { $0.count > 0 ? [] : ["count must be positive"] }
        XCTAssertEqual(checked.name, "two")

        do {
            _ = try await ask.object(.coder, prompt("t.obj"), as: Thing.self, budget: .card) { _ in ["never good enough"] }
            XCTFail("the check never accepts")
        } catch let error as ForgeError {
            XCTAssertEqual(error, .model(purpose: "t.obj", problems: ["never good enough"]))
        }
    }
}
