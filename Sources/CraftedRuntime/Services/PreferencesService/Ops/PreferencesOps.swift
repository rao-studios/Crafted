import CraftedCore
import Foundation

/// The preferences' one mutation, as a value.
public enum PreferencesOps {
    public static func apply(_ kind: PreferencesService.Set.Meta.Kind, to state: inout PreferencesService.Center.State) {
        switch kind {
        case .role(let role): state.role = role
        case .creditName(let name): state.creditName = String(name.prefix(120))
        case .creditLink(let link): state.creditLink = String(link.prefix(400))
        case .appearance(let choice): state.appearance = choice
        case .reset: state = .init()
        }
    }
}
