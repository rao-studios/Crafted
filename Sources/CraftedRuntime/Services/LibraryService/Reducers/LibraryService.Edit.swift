import CraftedCore
import Foundation
import Granite
import GraniteAgents

extension LibraryService {
    /// One change to one generation: its listing saved, its icon set or cleared, or the whole generation deleted. One
    /// reducer for the four, since they share a backend (the store), a lane and a shape (write, then read it back).
    public struct Edit: GraniteReducer {
        public typealias Center = LibraryService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Request: Sendable {
                case saveListing(String, AgentListing)
                case setIcon(String, URL)
                case removeIcon(String)
                case delete(String)

                public var id: String {
                    switch self {
                    case .saveListing(let id, _), .setIcon(let id, _), .removeIcon(let id), .delete(let id): return id
                    }
                }
            }
            public var ticket: UUID
            public var request: Request
            public init(ticket: UUID, request: Request) { self.ticket = ticket; self.request = request }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            state.editing = meta.request.id
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            let library = Live.service(LibraryService.self)
            let store = LibraryService.store
            return .run {
                do {
                    let reply = try await LibraryService.lane.run { try await LibraryOps.perform(meta.request, store: store) }
                    let entry = await LibraryOps.entry(meta.request.id, store: store)
                    library.set(.one(id: meta.request.id, entry))
                    library.set(.editing(nil))
                    await LibraryService.tickets.resolve(meta.ticket, with: reply)
                } catch {
                    library.set(.problem(error.localizedDescription))
                    library.set(.editing(nil))
                    await LibraryService.tickets.fail(meta.ticket, error)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
