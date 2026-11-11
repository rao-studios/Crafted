import Foundation

/// What a run says as it goes: a line of progress, then its answer.
public enum AgentFrame: Sendable {
    case note(String)
    case answered(AgentResult)

    public var result: AgentResult? {
        if case .answered(let result) = self { return result }
        return nil
    }
}
