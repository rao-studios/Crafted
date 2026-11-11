import Foundation

/// Tips, totals and shares, to the cent. The sample port: what a model writes under TipMathContract.
public enum TipMath: TipMathContract {
    struct Presets: Decodable {
        let service: [String: Double]
    }

    public static func percent(for service: String) throws -> Double {
        let presets = try CoreResources.json(Presets.self, "tip-presets.json")
        guard let percent = presets.service[service] else {
            throw CoreFailure.invalid("There is no service level called \(service): use " + presets.service.keys.sorted().joined(separator: ", ") + ".")
        }
        return percent
    }

    public static func breakdown(bill: Double, percent: Double, people: Int) throws -> TipBreakdown {
        guard bill >= 0 else { throw CoreFailure.invalid("The bill is \(bill): give an amount of zero or more.") }
        guard (0...100).contains(percent) else { throw CoreFailure.invalid("A tip of \(percent)% is out of range: give 0 to 100.") }
        guard people >= 1 else { throw CoreFailure.invalid("\(people) people cannot share a bill: give one or more.") }
        let tip = cents(bill * percent / 100)
        let total = cents(bill + tip)
        return TipBreakdown(bill: bill, percent: percent, tip: tip, total: total, perPerson: cents(total / Double(people)))
    }

    public static func shares(total: Double, people: Int) throws -> [Double] {
        guard people >= 1 else { throw CoreFailure.invalid("\(people) people cannot share a bill: give one or more.") }
        let all = Int((total * 100).rounded())
        let base = all / people
        let left = all % people
        return (0..<people).map { Double(base + ($0 < left ? 1 : 0)) / 100 }
    }

    static func cents(_ amount: Double) -> Double { (amount * 100).rounded() / 100 }
}
