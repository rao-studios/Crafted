//  WHAT: Home, the library: a watercolour leaf (Fourvière under its large gold sky) that takes a dropped folder, the
//        confirmation card a drop opens (what the folder holds, as which role, Start), and below it the grid of every
//        generation Crafted has made.
//  IN:   EnvironmentService (the proposal), LibraryService (the grid), PreferencesService (the role), ForgeService
//        (whether a run is going: one at a time).
//  OUT:  CraftedAppRoot (propose, start, open, update from a folder, Finder, delete, resume).
//  PIN:  WORDS ON THE LEAF, CONTROLS BELOW IT. The drop prompt sits in the painting's sky; the card and the grid sit on
//        the window's ground.
//  PIN:  On drag-over a ring of knots (the icon's outline) appears and a brass bloom pools under the pointer.

import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

struct Home: GraniteComponent {
    @Command var center: Center
    @Relay var environment: EnvironmentService
    @Relay var library: LibraryService
    @Relay var preferences: PreferencesService
    @Relay var forge: ForgeService

    /// A drop's card and a run's percent on its tile show as they move.
    @StateObject var clock = RelayClock([.on(EnvironmentService.self), .on(LibraryService.self), .on(PreferencesService.self),
                                         .on(ForgeService.self)])
}

extension Home {
    /// The leaf's drag-over and the grid's dialog: only this page's controls touch them.
    struct Center: GraniteCenter {
        struct State: GraniteState {
            /// A folder is being dragged over the leaf.
            var targeted = false
            /// Where the pointer is over the leaf, 0…1 each way: where the bloom pools.
            var pointerX: Double = 0.5
            var pointerY: Double = 0.5
            /// The generation whose deletion waits for a confirmation.
            var pendingDelete: String?
        }

        @Store var state: State
    }
}
