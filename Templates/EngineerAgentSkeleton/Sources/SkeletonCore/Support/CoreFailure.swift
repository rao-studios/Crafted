//  WHAT: How the logic says a call cannot be done: an input it cannot take (an unknown unit, a negative count), a
//        carried table it cannot find. The agent reads each as a refusal whose sentence is the fix.
//  PIN:  ONE SENTENCE, ITS FIX IN IT. "Unknown unit furlong: use km, m, mi or ft." A caller corrects the call from
//        the sentence alone.

import Foundation

public enum CoreFailure: Error, Equatable, Sendable, CustomStringConvertible {
    /// The input cannot be taken as it is; the sentence says what would be.
    case invalid(String)
    /// A carried file is not where the bundle should be.
    case missingResource(String, tried: [String])
    /// A unit's body was never written. Never shipped: a package that holds one is refused before it leaves.
    case notPorted(String)

    public var description: String {
        switch self {
        case .invalid(let sentence): return sentence
        case .missingResource(let name, let tried):
            return "The carried file \(name) was not found (looked in \(tried.prefix(3).joined(separator: ", "))): reinstall the agent."
        case .notPorted(let function): return "\(function) is not ported."
        }
    }
}
