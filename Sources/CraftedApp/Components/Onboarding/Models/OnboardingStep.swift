import Foundation

/// The onboarding, in order.
enum OnboardingStep: Int, CaseIterable, Identifiable, Codable {
    case welcome
    case models
    case role
    case done

    var id: Int { rawValue }

    /// The step bar's word.
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .models: return "Models"
        case .role: return "Your role"
        case .done: return "Ready"
        }
    }

    var symbol: String {
        switch self {
        case .welcome: return "hand.wave"
        case .models: return "cpu"
        case .role: return "person.crop.circle"
        case .done: return "checkmark.circle"
        }
    }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}
