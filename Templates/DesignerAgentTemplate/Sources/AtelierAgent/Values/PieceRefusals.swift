import AtelierKit
import GraniteAgents

/// The kit's errors as the answer standard (granite-answer/1) counts them: each a fix the call or the host can make.
/// A failed render is neither: it is the package's fault, said as it is.
extension PieceError: AgentRefusing {
    public var refusal: AgentRefusal {
        switch self {
        case .noModel: return AgentRefusal(.host, description)
        case .spec, .call: return AgentRefusal(.call, description)
        case .empty: return AgentRefusal(.model, description)
        case .style, .resources, .unwritable: return AgentRefusal(.host, description)
        case .render: return AgentRefusal(.device, description)
        }
    }
}
