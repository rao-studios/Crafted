//  WHAT: Crafted's first run: welcome, both models downloaded (or found where Craft put them), the person's role, then
//        Crafted opens. Locked until both models are on disk and a role is chosen.
//  IN:   ModelService (what is here, a download's progress), EnvironmentService (this Mac), PreferencesService (role).
//  OUT:  ModelService (download both, cancel), PreferencesService (role), CraftedAppRoot (Done).
//  PIN:  Nothing downloads until the person clicks. A copy Craft downloaded is found and the step is already green.

import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

struct Onboarding: GraniteComponent {
    @Command var center: Center
    @Relay var models: ModelService
    @Relay var environment: EnvironmentService
    @Relay var preferences: PreferencesService

    /// Download progress shows as it moves; this Mac shows once it is read.
    @StateObject var clock = RelayClock([.on(ModelService.self), .on(EnvironmentService.self), .on(PreferencesService.self)])
}

extension Onboarding {
    /// The walk through the steps; what each step shows is a service's.
    struct Center: GraniteCenter {
        struct State: GraniteState {
            var step: OnboardingStep = .welcome
            /// Done could not open Crafted: what is still missing.
            var stillMissing: String?
        }

        @Store var state: State
    }
}
