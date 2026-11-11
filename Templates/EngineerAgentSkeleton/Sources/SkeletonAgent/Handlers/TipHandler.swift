import Foundation

/// `tip`: the tip and the total, as facts.
enum TipHandler: CommandHandler {
    static func run(_ arguments: TipArguments, _ kit: CommandKit) async throws -> [Product] {
        let percent = try arguments.percent ?? TipMath.percent(for: arguments.service ?? "good")
        let breakdown = try TipMath.breakdown(bill: arguments.bill, percent: percent, people: 1)
        return [
            .value("tip", breakdown.tip),
            .value("total", breakdown.total),
            .value("percent", breakdown.percent, unit: "%"),
            .say("A \(FactValue.format(percent))% tip on \(FactValue.format(arguments.bill)) is \(FactValue.format(breakdown.tip)), "
                + "\(FactValue.format(breakdown.total)) in all."),
        ]
    }
}
