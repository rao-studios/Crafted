import Foundation

/// The onboarding gate: Crafted is not functional until both models are on disk and a role is chosen.
///
/// PIN: COMPUTED FROM DISK (and the stored role) at launch and at Done, never kept as a flag across launches, because a
/// model removed between runs (in Craft, too: the copy is shared) must close the gate again.
enum OnboardingPhase: Equatable, Sendable {
    /// Launch has not read the disk yet.
    case checking
    /// A model or the role is missing: the onboarding window is the app.
    case locked
    case open
}
