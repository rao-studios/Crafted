import CraftedCore
import Foundation
import Granite

extension EnvironmentService {
    /// The single writer. The mutation is `EnvironmentOps.apply`, tested as a value.
    ///
    /// PIN: SYNCHRONOUS (`thread: nil`). Every send comes through a helper that hops to main, so the commit lands in
    /// the sending turn and the root reads back what it wrote.
    struct Set: GraniteReducer {
        typealias Center = EnvironmentService.Center
        init() {}

        struct Meta: GranitePayload {
            enum Kind: Sendable {
                case activated(Bool)
                case machine(DeviceProfile)
                case onboarding(OnboardingPhase)
                case held(URL)
                /// The held folders were taken; the list empties.
                case heldTaken
                case route(Route)
                /// A folder proposed by a drop; nil clears the card.
                case proposal(FolderProposal?)
                /// What `Inspect` counted in the proposed folder.
                case counted(folder: URL, files: Int?, images: Int?, capped: Bool, problem: String?)
                case settingsSection(SettingsSection)
                /// The arrow keys in Settings' sidebar: a page on, or back, stopping at the ends.
                case settingsStep(Int)
                case reset
            }
            var kind: Kind
            init(kind: Kind) { self.kind = kind }
        }

        @Payload var meta: Meta?

        func reduce(state: inout Center.State) {
            guard let meta else { return }
            EnvironmentOps.apply(meta.kind, to: &state)
        }

        var thread: DispatchQueue? { nil }
    }
}
