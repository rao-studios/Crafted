import Foundation
import GraniteAgents

/// What the emitters gather for one call: facts, notes, files to land, what to hand on; then the answer.
struct EmitDraft: Sendable {
    let command: String
    var place: FilePlace
    var facts: [Fact] = []
    var notes: [String] = []
    var files: [PlannedFile] = []
    var problems: [AgentProblem] = []
    var handoffSummary: String?
    var asks: [String] = []

    init(command: String, place: FilePlace) {
        self.command = command
        self.place = place
    }

    mutating func plan(_ name: String, suffix: String, data: Data, kind: String, what: String, schema: String? = nil) {
        files.append(PlannedFile(path: place.path(name, suffix: suffix), data: data, kind: kind, name: name, what: what, schema: schema))
    }

    func answer(landed: [LandedFile], expected: [AgentExpected]) -> AgentResult {
        let paths = landed.map(\.path)
        let made = landed.map { AgentMade(kind: $0.planned.kind, name: $0.planned.name, path: $0.path, state: $0.existed ? .rewritten : .written) }
        let payloads = landed.compactMap { file in file.planned.schema.map { AgentPayload(path: file.path, schema: $0) } }
        var notes = notes
        for file in landed { notes.append("Wrote \(file.planned.what) to \(file.planned.path).") }
        return AgentResult(command: command, path: paths.first, paths: paths, facts: facts, notes: notes, made: made,
                           expected: expected, problems: problems, payloads: payloads)
    }
}
