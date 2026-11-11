import Foundation

/// `split`: the total, each share as a table, and a report of the split.
enum SplitHandler: CommandHandler {
    static func run(_ arguments: SplitArguments, _ kit: CommandKit) async throws -> [Product] {
        let percent = try arguments.percent ?? TipMath.percent(for: arguments.service ?? "good")
        let breakdown = try TipMath.breakdown(bill: arguments.bill, percent: percent, people: arguments.people)
        let shares = try TipMath.shares(total: breakdown.total, people: arguments.people)
        let rows = shares.enumerated().map { ["\($0.offset + 1)", FactValue.format($0.element)] }
        let report = Report(name: "split", title: "Splitting \(FactValue.format(breakdown.total))",
                            subtitle: "\(arguments.people) people, a \(FactValue.format(percent))% tip", blocks: [
                                .facts([Fact("bill", .number(arguments.bill)), Fact("tip", .number(breakdown.tip)),
                                        Fact("total", .number(breakdown.total))]),
                                .table(columns: ["person", "share"], rows: rows),
                                .note("Shares are whole cents; the first shares take any cent left over."),
                            ])
        return [
            .value("total", breakdown.total),
            .value("perPerson", breakdown.perPerson),
            .csv("shares", columns: ["person", "share"], rows: rows),
            .report(report),
            .say("\(FactValue.format(breakdown.total)) split \(arguments.people) ways is about \(FactValue.format(breakdown.perPerson)) each."),
        ]
    }
}
