//  WHAT: Settings › Models: Crafted's two models, one ModelCard each, with Download both, and what this Mac can hold.
//        Global by design: nothing here is tied to a generation.
//  IN:   ModelService, through its relay; EnvironmentService's `machine` for this Mac's line.
//  OUT:  ModelService (download, cancel, remove, refresh).
//  PIN:  Nothing downloads until the person clicks: together they are 37.9 GB.
//  PIN:  THE DISK IS LOOKED AT WHILE THE PAGE IS OPEN: a copy Craft finishes downloading, or removes, shows here on its
//        own, every few seconds.

import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

struct Models: GraniteComponent {
    @Command var center: Center
    @Relay var models: ModelService
    @Relay var environment: EnvironmentService

    /// A download's progress shows as it moves, not 0.2 s after it settles.
    @StateObject var clock = RelayClock([.on(ModelService.self), .on(EnvironmentService.self)])
}

extension Models {
    struct Center: GraniteCenter {
        struct State: GraniteState {}

        @Store var state: State
    }
}
