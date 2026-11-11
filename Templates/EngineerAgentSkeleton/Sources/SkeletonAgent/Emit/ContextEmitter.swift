//  WHAT: Products handed on to the next agent: one `crafted-handoff/1` file holding the facts, tables and texts, and
//        naming the files written beside it (JSON, files, series, reports as Markdown), with a note saying how to pass
//        it on.
//  PIN:  AT MOST 64 KB. Tables are cut from the bottom until the hand-off fits, and a cut table says so in its name.

import Foundation
import GraniteAgents

enum ContextEmitter {
    static func emit(_ products: [Product], into draft: inout EmitDraft, kit: CommandKit) throws {
        var tables: [HandoffTable] = []
        var texts: [HandoffText] = []
        for product in products {
            switch product.body {
            case .csv(let name, let columns, let rows): tables.append(HandoffTable(name: name, columns: columns, rows: rows))
            case .text(let name, let markdown): texts.append(HandoffText(name: name, markdown: markdown))
            case .report(let report): texts.append(HandoffText(name: report.name, markdown: ReportMarkdown.text(report)))
            default: OutputEmitter.emit(product, into: &draft)
            }
        }
        let files = draft.files.map { HandoffFile(path: $0.path, kind: $0.kind, what: $0.what) }
        let summary = draft.handoffSummary ?? draft.notes.first ?? "What `\(draft.command)` found."
        let at = ISO8601DateFormatter().string(from: kit.now)
        var handoff = Handoff(from: HandoffSource(word: SkeletonAgent.word, command: draft.command, at: at),
                              title: "\(SkeletonAgent.word) \(draft.command)", summary: summary, facts: draft.facts,
                              tables: tables, text: texts, files: files, asks: draft.asks)
        var data = try encoded(handoff)
        while data.count > Handoff.limit, let index = handoff.tables.indices.max(by: { handoff.tables[$0].rows.count < handoff.tables[$1].rows.count }),
              handoff.tables[index].rows.count > 1 {
            let kept = handoff.tables[index].rows.count / 2
            handoff.tables[index].rows = Array(handoff.tables[index].rows.prefix(kept))
            if !handoff.tables[index].name.hasSuffix("(cut)") { handoff.tables[index].name += " (cut)" }
            data = try encoded(handoff)
        }
        guard data.count <= Handoff.limit else {
            throw AgentRefusal(.call, "What `\(draft.command)` found is over 64 KB even cut: present it as output instead.")
        }
        draft.plan(draft.command, suffix: Handoff.suffix, data: data, kind: "handoff", what: "the hand-off for the next agent")
        let path = draft.files.last?.path ?? ""
        draft.notes.append("Handed on in \(path): give it to the next agent's call as `handoff`.")
    }

    private static func encoded(_ handoff: Handoff) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(handoff)
    }
}
