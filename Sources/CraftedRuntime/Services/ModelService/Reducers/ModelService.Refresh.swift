import CraftedCore
import CraftedMLX
import Foundation
import Granite
import GraniteAgents

extension ModelService {
    /// Reads the disk: each model's copy (any commit, no `.incomplete` markers), and this Mac's memory and free disk.
    public struct Refresh: GraniteReducer {
        public typealias Center = ModelService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public var ticket: UUID?
            public init(ticket: UUID?) { self.ticket = ticket }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            state.isRefreshing = true
        }

        public func effect(state: Center.State) -> GraniteEffect {
            let ticket = meta?.ticket
            let models = Live.service(ModelService.self)
            let home = ModelService.home
            return .run {
                let (statuses, fit) = ModelOps.read(home: home)
                models.set(.read(statuses, fit))
                if let ticket { await ModelService.tickets.resolve(ticket, with: .catalog(statuses)) }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
