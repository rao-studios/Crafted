//  WHAT: A stand-in for both models that answers from a script: canned replies keyed by the ask's purpose and a
//        piece of its text. It drives the real pipeline, the real templates, the real builds and the real zip, so
//        the whole flow is proven without loading a model (CRAFTED_MODELS=scripted, crafted-check --models scripted).
//  IN:   Fixtures/scripts/<folder name>.json, picked by the dropped folder's name (`bind(source:)`):
//
//        {"format": "crafted-script/1",
//         "answers": [
//           {"purpose": "engineer.brief", "text": "…"},
//           {"purpose": "engineer.card", "match": "convert.py", "json": {…}},
//           {"purpose": "engineer.unit", "match": "Conversions", "once": true, "text": "a body that fails to build"},
//           {"purpose": "engineer.unit", "match": "Conversions", "text": "the body that builds"}]}
//
//        The first answer whose purpose equals the ask's (or is "*") and whose `match` occurs in the prompt wins;
//        one marked `once` is spent when used, so a script can make the first try fail and the repair pass.
//  PIN:  NOT A MOCK MODE OF THE PRODUCT. It is a ForgeModel like the live one; the pipeline cannot tell them apart.

import CraftedCore
import Foundation

public actor ScriptedModel: ForgeModel {
    public struct Answer: Codable, Sendable {
        public var purpose: String
        public var match: String?
        public var text: String?
        public var json: JSONValue?
        public var once: Bool?
    }

    public struct Script: Codable, Sendable {
        public var format: String?
        public var answers: [Answer]
    }

    private let folder: URL
    private var answers: [Answer] = []
    private var spent: Swift.Set<Int> = []
    private var current: ForgeModelRole?
    private var scriptName: String?

    /// `folder` holds one script per fixture, named for the fixture's folder.
    public init(scripts folder: URL) {
        self.folder = folder
    }

    /// Where scripts live: `CRAFTED_SCRIPTS`, else Fixtures/scripts found upward from the executable or the
    /// working directory, else the app's bundled Scripts.
    public static func locateScripts() -> URL? {
        let fm = FileManager.default
        if let path = ProcessInfo.processInfo.environment["CRAFTED_SCRIPTS"], !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        var starts = [URL(fileURLWithPath: fm.currentDirectoryPath)]
        if let executable = Bundle.main.executableURL { starts.append(executable.deletingLastPathComponent()) }
        for start in starts {
            var folder = start
            for _ in 0..<8 {
                let candidate = folder.appendingPathComponent("Fixtures/scripts", isDirectory: true)
                if fm.fileExists(atPath: candidate.path) { return candidate }
                folder = folder.deletingLastPathComponent()
            }
        }
        if let resources = Bundle.main.resourceURL?.appendingPathComponent("Scripts", isDirectory: true),
           fm.fileExists(atPath: resources.path) { return resources }
        return nil
    }

    public func bind(source: URL) async {
        let name = source.lastPathComponent
        let url = folder.appendingPathComponent(name + ".json")
        scriptName = name
        spent = []
        guard let data = try? Data(contentsOf: url),
              let script = try? JSONDecoder().decode(Script.self, from: data) else {
            answers = []
            return
        }
        answers = script.answers
    }

    /// Loads answers directly (tests).
    public func load(_ script: Script) {
        answers = script.answers
        spent = []
    }

    public func resident() async -> ForgeModelRole? { current }

    public func prepare(_ role: ForgeModelRole) async throws { current = role }

    public func release() async { current = nil }

    public func text(_ role: ForgeModelRole, _ prompt: ModelPrompt, _ budget: ModelBudget) async throws -> ModelReply {
        current = role
        return try reply(prompt)
    }

    public func look(_ prompt: ModelPrompt, image: ModelImage, _ budget: ModelBudget) async throws -> ModelReply {
        current = .vision
        return try reply(prompt)
    }

    private func reply(_ prompt: ModelPrompt) throws -> ModelReply {
        let haystack = prompt.system + "\n" + prompt.user
        for (index, answer) in answers.enumerated() where !spent.contains(index) {
            guard answer.purpose == prompt.purpose || answer.purpose == "*" else { continue }
            if let match = answer.match, !haystack.contains(match) { continue }
            if answer.once == true { spent.insert(index) }
            let text: String
            if let json = answer.json, let data = try? json.data(pretty: false) {
                text = String(decoding: data, as: UTF8.self)
            } else {
                text = answer.text ?? ""
            }
            return ModelReply(text: text, promptTokens: haystack.count / 4, completionTokens: max(1, text.count / 4), seconds: 0.01)
        }
        let first = prompt.user.split(separator: "\n").first.map(String.init) ?? ""
        throw ForgeError.noScriptedAnswer(purpose: prompt.purpose,
                                          hint: "script \(scriptName ?? "none"); first line: \(first.prefix(120))")
    }
}
