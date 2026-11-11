import CraftedCore
import Foundation
import Granite

extension PreferencesService {
    /// The person's choices: `set` the only writer.
    public struct Center: GraniteCenter {
        public init() {}

        public struct State: GraniteState {
            /// Nil until the onboarding's role step: the gate stays shut without one.
            public var role: CraftedRole?
            /// The name a designer agent credits. macOS's full name until the person changes it.
            public var creditName: String = NSFullUserName()
            /// Where the credit links: a portfolio, a site. Optional.
            public var creditLink: String = ""
            public var appearance: AppearanceChoice = .system
            public init() {}

            /// The credit as a run takes it: nil when blank.
            public var credit: String? {
                let name = creditName.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : name
            }

            public var creditURL: String? {
                let link = creditLink.trimmingCharacters(in: .whitespacesAndNewlines)
                return link.isEmpty ? nil : link
            }
        }

        @Event public var set: Set.Reducer
        @Store(persist: PreferencesService.persistenceKey, autoSave: true, preload: true) public var state: State
    }
}
