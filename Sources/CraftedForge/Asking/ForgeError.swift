//  WHAT: The ways a run stops that are not the person's cancel: a model that gave nothing usable after its repairs,
//        a stage that cannot go on, a missing template, a gate the package could not pass.

import Foundation

public enum ForgeError: Error, LocalizedError, Equatable {
    /// The model's answer would not read as the shape asked for, after every repair.
    case model(purpose: String, problems: [String])
    /// The scripted model has no answer for a call: the fixture's script is missing it.
    case noScriptedAnswer(purpose: String, hint: String)
    case noToolchain(String)
    case template(String)
    case stage(String, String)
    case notFound(String)
    case gate(String)

    public var errorDescription: String? {
        switch self {
        case .model(let purpose, let problems):
            return "The model's answer for \(purpose) did not hold: " + problems.prefix(3).joined(separator: " ")
        case .noScriptedAnswer(let purpose, let hint):
            return "The scripted model has no answer for \(purpose) (\(hint)). Add one to the fixture's script."
        case .noToolchain(let reason):
            return "No Swift toolchain: \(reason)"
        case .template(let reason):
            return "Template: \(reason)"
        case .stage(let stage, let reason):
            return "\(stage): \(reason)"
        case .notFound(let what):
            return "\(what) was not found."
        case .gate(let reason):
            return reason
        }
    }
}
