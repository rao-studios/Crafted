//  WHAT: What a handler made, said as data: a sentence, a named value, a text, a JSON value, a table, a file, a
//        report, a series, or what to hand on. The emitters decide how each is written for the way the call asked to
//        be presented; a handler never writes a file.
//  OUT:  Emitter (Emit/).
//  PIN:  NAMES ARE FILE NAMES. A product's name becomes its file's name under the agent's folder (`report` named
//        "monthly totals" is monthly-totals.png), so a handler names what it made in words a person would use.

import Foundation

public struct Product: Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case say, value, text, json, csv, file, report, series, handoff
    }

    enum Body: Sendable {
        case say(String)
        case value(Fact)
        case text(name: String, markdown: String)
        case json(name: String, data: Data)
        case csv(name: String, columns: [String], rows: [[String]])
        case file(name: String, ext: String, data: Data)
        case report(Report)
        case series(TimeSeries)
        case handoff(summary: String, asks: [String])
    }

    let body: Body

    public var kind: Kind {
        switch body {
        case .say: return .say
        case .value: return .value
        case .text: return .text
        case .json: return .json
        case .csv: return .csv
        case .file: return .file
        case .report: return .report
        case .series: return .series
        case .handoff: return .handoff
        }
    }

    /// One sentence for the answer's notes.
    public static func say(_ sentence: String) -> Product { Product(body: .say(sentence)) }

    /// A named number, with its unit.
    public static func value(_ name: String, _ number: Double, unit: String? = nil) -> Product {
        Product(body: .value(Fact(name, .number(number), unit: unit)))
    }

    public static func value(_ name: String, _ number: Int, unit: String? = nil) -> Product {
        Product(body: .value(Fact(name, .number(Double(number)), unit: unit)))
    }

    public static func value(_ name: String, _ number: Decimal, unit: String? = nil) -> Product {
        Product(body: .value(Fact(name, .number(NSDecimalNumber(decimal: number).doubleValue), unit: unit)))
    }

    public static func value(_ name: String, _ text: String) -> Product { Product(body: .value(Fact(name, .text(text)))) }

    public static func value(_ name: String, _ flag: Bool) -> Product { Product(body: .value(Fact(name, .flag(flag)))) }

    /// A text in Markdown, written as `<name>.md`.
    public static func text(_ name: String, _ markdown: String) -> Product { Product(body: .text(name: name, markdown: markdown)) }

    /// Any encodable value, written as `<name>.json`.
    public static func json<T: Encodable>(_ name: String, _ value: T) throws -> Product {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return Product(body: .json(name: name, data: try encoder.encode(value)))
    }

    /// A table, written as `<name>.csv`; handed on as a table.
    public static func csv(_ name: String, columns: [String], rows: [[String]]) -> Product {
        Product(body: .csv(name: name, columns: columns, rows: rows))
    }

    /// Bytes of the handler's own making, written as `<name>.<ext>`.
    public static func file(_ name: String, ext: String, data: Data) -> Product {
        Product(body: .file(name: name, ext: ext, data: data))
    }

    /// A report: a PNG or paged PDF for Canvas, Markdown as output, a text when handed on.
    public static func report(_ report: Report) -> Product { Product(body: .report(report)) }

    /// A `craft-timeseries/1` series Canvas draws as a chart.
    public static func series(_ series: TimeSeries) -> Product { Product(body: .series(series)) }

    /// What the next agent should know and could ask next, when the call is handed on.
    public static func handoff(summary: String, asks: [String] = []) -> Product {
        Product(body: .handoff(summary: summary, asks: asks))
    }
}
