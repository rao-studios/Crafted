import Foundation

/// Products as files a person or a host reads: sentences become notes, values facts, texts and reports Markdown,
/// JSON and tables their own files, a series its `craft-timeseries/1` payload.
enum OutputEmitter {
    static func emit(_ products: [Product], into draft: inout EmitDraft) {
        for product in products { emit(product, into: &draft) }
    }

    static func emit(_ product: Product, into draft: inout EmitDraft) {
        switch product.body {
        case .say(let sentence): draft.notes.append(sentence)
        case .value(let fact): draft.facts.append(fact)
        case .text(let name, let markdown):
            draft.plan(name, suffix: ".md", data: Data(markdown.utf8), kind: "text", what: "the text \(name)")
        case .json(let name, let data):
            draft.plan(name, suffix: ".json", data: data, kind: "json", what: "\(name) as JSON")
        case .csv(let name, let columns, let rows):
            draft.plan(name, suffix: ".csv", data: Data(CSVText.text(columns: columns, rows: rows).utf8), kind: "csv",
                       what: "the table \(name) (\(rows.count) rows)")
        case .file(let name, let ext, let data):
            draft.plan(name, suffix: "." + ext.trimmingCharacters(in: CharacterSet(charactersIn: ".")), data: data, kind: "file", what: "the file \(name)")
        case .report(let report):
            draft.plan(report.name, suffix: ".md", data: Data(ReportMarkdown.text(report).utf8), kind: "report",
                       what: "the report \(report.title) as Markdown")
        case .series(let series):
            draft.plan(series.title, suffix: TimeSeries.suffix, data: SeriesFile.data(series), kind: "series",
                       what: "the series \(series.title)", schema: TimeSeries.schemaID)
        case .handoff(let summary, let asks):
            draft.handoffSummary = summary
            draft.asks += asks
            draft.notes.append(summary)
        }
    }
}
