//  WHAT: Settings: who you are to Crafted and how it looks (General), the two models (Models), and this build (About),
//        in Craft's window and sidebar, with a rule above About.
//  IN:   EnvironmentService (the page), PreferencesService (General). The Models page is the `Models` component, on its
//        own relay and clock: a download's progress redraws that page alone.
//  OUT:  PreferencesService (role, credit, appearance); CraftedAppRoot (the appearance applied at once).
//  PIN:  `Settings` here is this component, not SwiftUI's `Settings` scene: CraftedApp has no SwiftUI scenes.

import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

struct Settings: GraniteComponent {
    @Command var center: Center
    @Relay var environment: EnvironmentService
    @Relay var preferences: PreferencesService

    /// A page chosen and a control's own write show at once.
    @StateObject var clock = RelayClock([.on(EnvironmentService.self), .on(PreferencesService.self)])
}
