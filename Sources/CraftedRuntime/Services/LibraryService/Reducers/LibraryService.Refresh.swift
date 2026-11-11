import CraftedCore
import Foundation
import Granite
import GraniteAgents

extension LibraryService {
    /// Reads every generation, its listing and its icon from disk.
    public struct Refresh: GraniteReducer {
        public typealias Center = LibraryService.Center
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
            let library = Live.service(LibraryService.self)
            let store = LibraryService.store
            return .run {
                let snapshot = try? await LibraryService.lane.run { await LibraryOps.read(store) }
                if let snapshot { library.set(.read(snapshot)) } else { library.set(.refreshing(false)) }
                if let ticket { await LibraryService.tickets.resolve(ticket, with: .generations(snapshot?.generations ?? [])) }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
