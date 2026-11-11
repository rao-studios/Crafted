import Foundation
import GraniteAgents

/// The logic's failures as the answer standard counts them: an input it cannot take is the caller's to fix (`call`);
/// a carried table that is missing is the install's (`host`).
extension CoreFailure: AgentRefusing {
    public var refusal: AgentRefusal {
        switch self {
        case .invalid: return AgentRefusal(.call, description)
        case .missingResource: return AgentRefusal(.host, description)
        case .notPorted: return AgentRefusal(.host, description)
        }
    }
}
