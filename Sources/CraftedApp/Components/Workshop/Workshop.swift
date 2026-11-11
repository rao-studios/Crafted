//  WHAT: The Workshop window's one page at a time: Home (the drop leaf and the library), or a generation's run, its
//        interpretations or its listing, by the route and where the run stands (WorkshopRules).
//  IN:   EnvironmentService (the route), ForgeService (the live run), LibraryService (the records).
//  OUT:  Home, Generation, Interpretations, Listing.
//  PIN:  THE ROUTE IS A SERVICE'S, NOT THIS CENTER'S: the menus, the Dock and the self-test move it through the root.

import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

struct Workshop: GraniteComponent {
    @Command var center: Center
    @Relay var environment: EnvironmentService
    @Relay var forge: ForgeService
    @Relay var library: LibraryService

    /// A run's phase turning (analysing → choosing → done) moves the page within a frame.
    @StateObject var clock = RelayClock([.on(EnvironmentService.self), .on(ForgeService.self), .on(LibraryService.self)])
}

extension Workshop {
    struct Center: GraniteCenter {
        struct State: GraniteState {}

        @Store var state: State
    }
}

extension Workshop {
    var view: some View {
        let route = environment.state.route
        let id = route.generationID
        let page = WorkshopRules.page(route, run: forge.state.run,
                                      record: id.flatMap { library.state.generation($0) })
        return Group {
            switch page {
            case .home: Home()
            case .generation(let id): GenerationPage(id: id)
            case .interpretations(let id): Interpretations(id: id)
            case .listing(let id): Listing(id: id, mode: .page)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.craftBG)
        .task { library.refreshSoon() }
    }
}
