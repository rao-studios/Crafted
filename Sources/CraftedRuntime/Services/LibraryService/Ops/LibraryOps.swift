//  WHAT: The library's decisions as values (the writer's mutation) and its two kinds of work: a read of the folder,
//        and one edit through the store.
//  OUT:  LibraryService's reducers.

import CraftedCore
import Foundation

public enum LibraryOps {
    /// One generation as the library keeps it.
    public struct Entry: Equatable, Sendable {
        public var generation: Generation
        public var listing: AgentListing?
        public var icon: String?
    }

    /// The whole folder, as read.
    public struct Snapshot: Equatable, Sendable {
        public var generations: [Generation]
        public var listings: [String: AgentListing]
        public var icons: [String: String]
    }

    public static func apply(_ kind: LibraryService.Set.Meta.Kind, to state: inout LibraryService.Center.State) {
        switch kind {
        case .read(let snapshot):
            if snapshot.icons != state.icons { state.iconRevision += 1 }
            state.generations = snapshot.generations
            state.listings = snapshot.listings
            state.icons = snapshot.icons
            state.isRefreshing = false
            state.hasRead = true
        case .one(let id, let entry):
            guard let entry else {
                state.generations.removeAll { $0.id == id }
                state.listings[id] = nil
                state.icons[id] = nil
                state.iconRevision += 1
                return
            }
            if let index = state.generations.firstIndex(where: { $0.id == id }) {
                state.generations[index] = entry.generation
            } else {
                state.generations.append(entry.generation)
            }
            state.generations.sort { $0.updated > $1.updated }
            state.listings[id] = entry.listing
            state.icons[id] = entry.icon
            state.iconRevision += 1
        case .refreshing(let on):
            state.isRefreshing = on
        case .editing(let id):
            state.editing = id
        case .problem(let text):
            state.problem = text
        case .reset:
            state = .init()
        }
    }

    // MARK: - Work

    public static func read(_ store: GenerationStore) async -> Snapshot {
        let generations = await store.list()
        var listings: [String: AgentListing] = [:]
        var icons: [String: String] = [:]
        for generation in generations {
            listings[generation.id] = await store.listing(generation.id)
            icons[generation.id] = await store.icon(generation.id)?.path
        }
        return Snapshot(generations: generations, listings: listings, icons: icons)
    }

    public static func entry(_ id: String, store: GenerationStore) async -> Entry? {
        guard let generation = await store.record(id) else { return nil }
        return Entry(generation: generation, listing: await store.listing(id), icon: await store.icon(id)?.path)
    }

    static func perform(_ request: LibraryService.Edit.Meta.Request, store: GenerationStore) async throws -> LibraryReply {
        switch request {
        case .saveListing(let id, let listing):
            guard await store.record(id) != nil else { throw LibraryError.notFound(id) }
            try await store.saveListing(listing, id)
            return .listing(await store.listing(id) ?? listing)
        case .setIcon(let id, let url):
            guard await store.record(id) != nil else { throw LibraryError.notFound(id) }
            try await store.setIcon(from: url, id)
            return .done
        case .removeIcon(let id):
            try await store.removeIcon(id)
            return .done
        case .delete(let id):
            try await store.delete(id)
            return .done
        }
    }

    /// The keys a form's save changed against what was on disk, added to `edited`: a suggestion never overwrites them.
    public static func marking(_ draft: AgentListing, against saved: AgentListing?) -> AgentListing {
        var draft = draft
        guard let saved else { return draft }
        if draft.name != saved.name { draft.edited.insert(.name) }
        if draft.word != saved.word { draft.edited.insert(.word) }
        if draft.tagline != saved.tagline { draft.edited.insert(.tagline) }
        if draft.category != saved.category { draft.edited.insert(.category) }
        if draft.keywords != saved.keywords { draft.edited.insert(.keywords) }
        if draft.platforms != saved.platforms { draft.edited.insert(.platforms) }
        if draft.license != saved.license { draft.edited.insert(.license) }
        if draft.credit != saved.credit { draft.edited.insert(.credit) }
        draft.edited.formUnion(saved.edited)
        return draft
    }
}
