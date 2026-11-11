//  WHAT: The environment Crafted runs in, as the app sees it: the onboarding gate and the folders it held, which page
//        the Workshop shows (the library or one generation), a folder proposed by a drop and what it holds, Settings'
//        page, whether Crafted is the frontmost app, and this Mac (`DeviceProfile`), read once.
//  IN:   CraftedAppRoot (the gate, a drop, the Dock, activation, routes), Settings' sidebar, the onboarding.
//  OUT:  EnvironmentService+Center, Reducers/EnvironmentService.{Set,Machine,Inspect}, Ops/EnvironmentOps.
//  PIN:  ONE PLACE TO ASK. A page that needs the route, the gate or this Mac reads this service; AppKit's menus and the
//        Dock write it through the root, which is why the route is here and not in the Workshop's center.
//  PIN:  `Set` COMMITS IN THE SENDING TURN (`thread: nil`): every send comes through the main-hopping helper, so the
//        root reads back the route it just wrote.

import CraftedCore
import Foundation
import Granite
import GraniteAgents

struct EnvironmentService: GraniteService {
    @Service(.online) var center: Center
    init() {}

    static let tickets = GraniteTickets<DeviceProfile>()
}

extension EnvironmentService: @unchecked Sendable {}

extension EnvironmentService {
    /// The service's one writer, from anywhere: the change goes to `Set` on main.
    func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// This Mac, read the first time anyone asks and kept for the run.
    func machine() async throws -> DeviceProfile {
        let ticket = await Self.tickets.open()
        let service = self
        onMain { service.center.machine.send(Machine.Meta(ticket: ticket.id)) }
        return try await Self.tickets.wait(ticket.id)
    }

    /// Counts what a proposed folder holds (files, pictures), for the confirmation card.
    func inspect(_ folder: URL) {
        let service = self
        onMain { service.center.inspect.send(Inspect.Meta(folder: folder)) }
    }
}
