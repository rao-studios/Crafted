//  WHAT: The strategy ladder a unit climbs when its port fails, cheapest first: write from the contract; repair with
//        trimmed, located diagnostics and a hint; regenerate from a simplified contract; re-read more of the source;
//        change the Swift idiom; split the unit into one function at a time.
//  PIN:  BOUNDED. Each strategy has a cap; the unit's whole budget is ForgeOptions.unitAttempts (about 20). A spent
//        budget parks the unit and the person decides.

import Foundation

public enum PortStrategy: String, Codable, Sendable, CaseIterable {
    case write, repair, simplify, reread, idiom, split

    /// The order a unit climbs.
    public static let ladder: [PortStrategy] = [.write, .repair, .simplify, .reread, .idiom, .split]

    /// Attempts a strategy may take before the next.
    public var cap: Int {
        switch self {
        case .write: return 1
        case .repair: return 4
        case .simplify, .reread, .idiom: return 2
        case .split: return 8
        }
    }

    /// What the prompt asks for beyond the contract.
    var instruction: String {
        switch self {
        case .write: return "Write the file from the contract and the source."
        case .repair: return "Your last file failed. Fix exactly what the diagnostics say; change nothing else."
        case .simplify: return "Earlier tries failed. Write the simplest correct file: plain loops and ifs, no helpers beyond what the contract needs, the source's arithmetic exactly."
        case .reread: return "Earlier tries failed. Read the wider source below again, and write the file from it."
        case .idiom: return "Earlier tries failed. Use a different Swift idiom: no generics, no closures passed around, no protocol extensions, no Decimal unless the contract says; Double arithmetic written out step by step."
        case .split: return "Earlier tries failed. Write only the one function named below, as `public static func` with the contract's exact signature; nothing else."
        }
    }
}
