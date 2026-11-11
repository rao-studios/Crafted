//  WHAT: A command's canonical call made as a host makes it: JSON in through the roster's entry, a fresh project folder,
//        no host model; the answer read back, held to `granite-answer/1`, to the call's expected facts, and to the files
//        it names being on disk.
//  IN:   Calls/<command>.call.json beside this file.
//  OUT:  Generated/CallTests.swift, a test per command; the forge runs one command's test as a rung of its port.

import Foundation
import GraniteAgents
import XCTest
@testable import SkeletonAgent

enum CallHarness {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Calls", isDirectory: true)

    static func call(_ command: String) throws -> CallFile {
        let url = folder.appendingPathComponent("\(command).call.json")
        guard let data = try? Data(contentsOf: url) else {
            throw AgentRefusal(.call, "\(command) has no canonical call at Calls/\(command).call.json")
        }
        return try JSONDecoder().decode(CallFile.self, from: data)
    }

    /// A fresh project folder holding the call's files.
    static func project(_ call: CallFile) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("call-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for (path, text) in call.files ?? [:] {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }
        return root
    }

    /// The answer's JSON and decoded value for `input` in `directory`.
    static func perform(_ input: [String: CallJSON], in directory: URL, model: (any AgentHostModel)? = nil) async throws -> (Data, AgentResult) {
        var input = input
        input["directory"] = .string(directory.path)
        let data = try JSONEncoder().encode(input)
        let answer = try await AnyAgentPackage(SkeletonAgent.self).perform(data, host: AgentHost(directory: directory.path, model: model))
        return (answer, try JSONDecoder().decode(AgentResult.self, from: answer))
    }

    static func check(command: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let call = try call(command)
        XCTAssertEqual(call.command, command, "the call file is the command's", file: file, line: line)
        let directory = try project(call)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (answer, result) = try await perform(call.input, in: directory)
        let object = try JSONSerialization.jsonObject(with: answer) as? [String: Any]
        XCTAssertEqual(object?["format"] as? String, AgentAnswerStandard.format, "the runner stamped granite-answer/1", file: file, line: line)
        XCTAssertEqual(result.command, command, file: file, line: line)
        for path in result.paths {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "\(path) is on disk", file: file, line: line)
        }
        guard let expect = call.expect else { return }
        let tolerance = expect.tolerance ?? 1e-6
        for (name, value) in expect.facts ?? [:] {
            guard let fact = result.fact(name) else {
                XCTFail("the answer has no fact \(name): it has \(result.facts.map(\.name))", file: file, line: line)
                continue
            }
            switch (value, fact.value) {
            case (.number(let wanted), .number(let got)):
                XCTAssertEqual(got, wanted, accuracy: tolerance, "fact \(name)", file: file, line: line)
            case (.string(let wanted), .text(let got)):
                XCTAssertEqual(got, wanted, "fact \(name)", file: file, line: line)
            case (.bool(let wanted), .flag(let got)):
                XCTAssertEqual(got, wanted, "fact \(name)", file: file, line: line)
            default:
                XCTFail("fact \(name) is \(fact.value), expected \(value)", file: file, line: line)
            }
        }
        if let files = expect.files { XCTAssertEqual(result.paths.count, files, "files written: \(result.paths)", file: file, line: line) }
        for words in expect.notes ?? [] {
            XCTAssertTrue(result.notes.contains { $0.contains(words) }, "a note says \(words): \(result.notes)", file: file, line: line)
        }
    }
}
