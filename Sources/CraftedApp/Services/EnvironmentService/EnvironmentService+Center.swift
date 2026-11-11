import CraftedCore
import Foundation
import Granite
import GraniteAgents

extension EnvironmentService {
    /// The environment's state and its events: `set` the only writer; `machine` and `inspect` the work.
    struct Center: GraniteCenter {
        init() {}

        /// PIN: never persisted (a `TransientState`): every field describes this run of the app.
        struct State: TransientState {
            /// Crafted is the frontmost app.
            var isActive = false
            var onboarding: OnboardingPhase = .checking
            /// Folders asked for while the gate was shut, in order.
            var heldFolders: [URL] = []
            /// What the Workshop shows.
            var route: Route = .library
            /// A folder dropped (on Home or the Dock) waiting for the person's Start.
            var proposal: FolderProposal?
            /// Settings' page: environment state so a deep link lands whether or not the window is open.
            var settingsSection: SettingsSection = .general
            /// This Mac: the chip, the memory, Metal's working set. Nil until first asked (`machine()`).
            var machine: DeviceProfile?
            init() {}
        }

        @Event var set: Set.Reducer
        @Event var machine: Machine.Reducer
        @Event var inspect: Inspect.Reducer
        @Store var state: State
    }
}
