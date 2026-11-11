import Foundation
import GraniteAgents
import XCTest
@testable import SkeletonAgent

/// The emitters, without WebKit: products written as output (a series as its craft-timeseries/1 payload, named in the
/// answer's payloads), and handed on as context (facts, tables and texts in one crafted-handoff/1 file).
final class EmitTests: XCTestCase {
    func kit(_ directory: URL) throws -> CommandKit {
        try CommandKit(command: "emit", input: AgentInput(directory: directory.path), host: AgentHost(directory: directory.path), note: { _ in })
    }

    func products() throws -> [Product] {
        let series = TimeSeries(title: "Daily totals", unit: "USD", interval: "1d", asOf: "2026-11-09", series: [
            TimeSeriesLine(id: "total", label: "Total", points: [TimeSeriesPoint(t: "2026-11-08", v: 10), TimeSeriesPoint(t: "2026-11-09", v: 12.5)]),
        ])
        return [.value("total", 12.5, unit: "USD"), .say("Two days."), .csv("days", columns: ["day", "total"], rows: [["8", "10"], ["9", "12.5"]]),
                .series(series), .text("summary", "Two days, rising."), try .json("raw", ["a": 1])]
    }

    func testOutputWritesEachFileAndNamesTheSeriesAsAPayload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("emit-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await Emitter.emit(try products(), command: "emit", presentation: .output, output: nil, kit: try kit(directory))
        XCTAssertEqual(result.paths.map { ($0 as NSString).lastPathComponent }.sorted(), ["daily-totals.timeseries.json", "days.csv", "raw.json", "summary.md"])
        XCTAssertEqual(result.payloads.map(\.schema), [TimeSeries.schemaID])
        let payload = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: result.payloads[0].path))) as? [String: Any]
        XCTAssertEqual(payload?["schema"] as? String, TimeSeries.schemaID)
        XCTAssertEqual(result.fact("total")?.value, .number(12.5))
        XCTAssertTrue(result.notes.contains("Two days."))
        let answer = try JSONEncoder().encode(result)
        let object = try XCTUnwrap(AgentJSON(data: answer).flatMap { if case .object(let o) = $0 { return o } else { return nil } })
        let kinds = ["text", "json", "csv", "series", "handoff", "report", "file"].map { AgentMake(kind: $0, what: $0, into: ["*"]) }
        XCTAssertEqual(AgentAnswerCheck.problems(in: object, word: "w", makes: kinds, directory: directory.path), [], "the answer keeps granite-answer/1")
    }

    func testContextHandsOnFactsTablesAndTextsInOneFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("emit-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await Emitter.emit(try products(), command: "emit", presentation: .context, output: "handed", kit: try kit(directory))
        let path = try XCTUnwrap(result.paths.first { $0.hasSuffix(Handoff.suffix) })
        XCTAssertTrue(path.contains("/handed/"), "the call's output folder")
        let handoff = try JSONDecoder().decode(Handoff.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertEqual(handoff.facts.map(\.name), ["total"])
        XCTAssertEqual(handoff.tables.map(\.name), ["days"])
        XCTAssertEqual(handoff.text.map(\.name), ["summary"])
        XCTAssertEqual(Set(handoff.files.map(\.kind)), ["series", "json"], "files written beside it are named in it")
        XCTAssertTrue(result.notes.contains { $0.contains("give it to the next agent's call as `handoff`") })
    }
}
