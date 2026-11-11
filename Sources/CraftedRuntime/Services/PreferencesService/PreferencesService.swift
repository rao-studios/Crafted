//  WHAT: What the person has told Crafted about themselves: their role (designer or engineer), the name and link a
//        designer agent credits, and how the app looks.
//  IN:   The onboarding's role step, Settings › General, Home's role pill.
//  OUT:  PreferencesService+Center, Reducers/PreferencesService.Set, Ops/PreferencesOps.
//  PIN:  PERSISTED, VERSIONED (`crafted.persistence.preferences.0001`). The store restores after the service exists:
//        every first use is gated on `isLoaded` (the onboarding gate, the root's launch). A self-test keeps its own
//        key so it never edits the person's preferences; `CRAFTED_PREFERENCES_KEY` moves it by hand.
//  PIN:  ONE ROLE. A run's role is fixed when it starts; changing it here changes the next drop, never a live run.
//  PIN:  `Set` COMMITS IN THE SENDING TURN (`thread: nil`): every send comes through the main-hopping helper and the
//        controls bound to it read back what they wrote.

import CraftedCore
import Foundation
import Granite
import GraniteAgents
import SwiftUI

public struct PreferencesService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    public static let persistenceKey: String = {
        let environment = ProcessInfo.processInfo.environment
        if let key = environment["CRAFTED_PREFERENCES_KEY"], !key.isEmpty { return key }
        if environment["CRAFTED_SELFTEST"] != nil { return "crafted.persistence.preferences.selftest" }
        return "crafted.persistence.preferences.0001"
    }()
}

extension PreferencesService: @unchecked Sendable {}

extension PreferencesService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// A control bound to one preference through the writer.
    @MainActor
    public func binding<V>(_ keyPath: KeyPath<Center.State, V>, _ kind: @escaping (V) -> Set.Meta.Kind) -> Binding<V> {
        Binding(get: { self.state[keyPath: keyPath] }, set: { self.set(kind($0)) })
    }
}
