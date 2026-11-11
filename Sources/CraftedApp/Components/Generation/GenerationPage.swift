//  WHAT: A generation's run: the gardens washing in with the run's real progress, the stage list beside it, the line
//        being read or written, the counts, elapsed time, the model and tokens/s; a question card when the run asks
//        one; the Listing & icon panel over it while it goes on; Cancel and Resume; a failure card.
//  IN:   ForgeService (the live run), LibraryService (the record, when the run is not live in this launch).
//  OUT:  ForgeService (decide, cancel), CraftedAppRoot (resume, the library).
//  PIN:  NAMED `GenerationPage`: `Generation` is CraftedCore's record, which the app names too.
//  PIN:  THE WASH NEVER LEADS THE ENGINE (WashProgress): each stage owns a band of the painting by weight; a stage with
//        no fraction creeps toward 85% of its band; the drawn wash eases toward the target at 20 fps while it moves.

import CraftedCore
import CraftedForge
import CraftedRuntime
import Granite
import SwiftUI

struct GenerationPage: GraniteComponent {
    @Command var center: Center
    @Relay var forge: ForgeService
    @Relay var library: LibraryService

    /// Progress, a stage turning and a question arriving show within a frame.
    @StateObject var clock = RelayClock([.on(ForgeService.self), .on(LibraryService.self)])

    let id: String

    init(id: String) {
        self.id = id
    }
}

extension GenerationPage {
    struct Center: GraniteCenter {
        struct State: GraniteState {
            /// The Listing & icon panel is open over the run.
            var showsListing = false
        }

        @Store var state: State
    }
}
