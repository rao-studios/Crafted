//  WHAT: Every generation Crafted has made, as the grid and the listing form show them: read from the generations
//        folder (disk is the truth), with the verbs that change one: save its listing, set or clear its icon, delete it.
//  IN:   GenerationStore (CraftedCore): one actor writes generation.json, listing.json and icon.png.
//  OUT:  LibraryService+Center, Reducers/LibraryService.{Set,Refresh,Edit}, Ops/LibraryOps.
//  PIN:  DISK IS THE TRUTH. The state is a read of ~/Library/Application Support/nyc.rao.crafted/Generations (CRAFTED_HOME
//        moves it); every edit reads its generation back after it writes, and the forge's progress lands in the
//        records it writes, which a refresh reads.
//  PIN:  A LEAF. Nothing here relays to another service; ForgeService relays down into this one (refreshSoon) when a
//        run's events change a record.

import CraftedCore
import Foundation
import Granite
import GraniteAgents

public struct LibraryService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    static let tickets = GraniteTickets<LibraryReply>()
    /// Edits and reads go one at a time: a save never races the refresh that follows it.
    static let lane = GraniteLane()
    /// The store every reducer reads and writes through; `.shared` unless the root connects another.
    static let stores = TransientRegistry<GenerationStore>()

    public static var store: GenerationStore { stores.get("store") ?? .shared }
}

extension LibraryService: @unchecked Sendable {}

extension LibraryService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// The root's boot: the store the reducers work through. Put before any send.
    public func connect(store: GenerationStore) { Self.stores.put("store", store) }

    /// Reads every generation and its listing again.
    @discardableResult
    public func refresh() async -> [Generation] {
        let ticket = await Self.tickets.open()
        hop { $0.center.refresh.send(Refresh.Meta(ticket: ticket.id)) }
        guard case .generations(let all)? = try? await Self.tickets.wait(ticket.id) else { return [] }
        return all
    }

    public func refreshSoon() { hop { $0.center.refresh.send(Refresh.Meta(ticket: nil)) } }

    /// The person's save: the form's values, with the keys they changed in `edited`. Answers the listing as saved.
    @discardableResult
    public func saveListing(_ listing: AgentListing, for id: String) async throws -> AgentListing {
        guard case .listing(let saved) = try await edit(.saveListing(id, listing)) else { throw LibraryError.badReply }
        return saved
    }

    /// Any picture as the agent's icon: normalised by the store to a square 1024 px PNG.
    public func setIcon(from image: URL, for id: String) async throws {
        _ = try await edit(.setIcon(id, image))
    }

    public func removeIcon(for id: String) async throws {
        _ = try await edit(.removeIcon(id))
    }

    /// Deletes a generation's folder: its record, listing, icon, run and package. The exported zips stay where saved.
    public func delete(_ id: String) async throws {
        _ = try await edit(.delete(id))
    }

    private func edit(_ request: Edit.Meta.Request) async throws -> LibraryReply {
        let ticket = await Self.tickets.open()
        hop { $0.center.edit.send(Edit.Meta(ticket: ticket.id, request: request)) }
        return try await Self.tickets.wait(ticket.id)
    }

    private func hop(_ body: @escaping @Sendable (LibraryService) -> Void) {
        let service = self
        onMain { body(service) }
    }
}

public enum LibraryReply: Sendable {
    case generations([Generation])
    case listing(AgentListing)
    case done
}

public enum LibraryError: Error, LocalizedError {
    case badReply
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .badReply: return "The library answered something unexpected."
        case .notFound(let id): return "Generation \(id) is not in the library."
        }
    }
}
