import CraftedCore
import CraftedRuntime
import Foundation

/// Where the listing form is shown: as a panel over a live run, or as the page of a finished generation.
enum ListingMode: Equatable {
    case panel
    case page
}

/// The form's fields as text, and the listing they make: the form edits strings (keywords and platforms as one line
/// each), the store keeps an `AgentListing`.
enum ListingDraft {
    /// The fields the form holds, from a saved listing.
    static func load(_ listing: AgentListing, into state: inout Listing.Center.State, id: String) {
        state.loadedFor = id
        state.base = listing
        state.name = listing.name
        state.word = listing.word
        state.tagline = listing.tagline
        state.category = listing.category
        state.keywords = listing.keywords.joined(separator: ", ")
        state.platforms = listing.platforms.joined(separator: ", ")
        state.license = listing.license
        state.creditName = listing.credit?.designer ?? ""
        state.creditLink = listing.credit?.url ?? ""
    }

    /// The listing the fields make, on top of what is saved (its read-only fields and its `edited` keys).
    static func listing(_ state: Listing.Center.State, saved: AgentListing?) -> AgentListing {
        let name = state.creditName.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = state.creditLink.trimmingCharacters(in: .whitespacesAndNewlines)
        return AgentListing(
            name: state.name.trimmingCharacters(in: .whitespacesAndNewlines),
            word: state.word.trimmingCharacters(in: .whitespacesAndNewlines),
            tagline: state.tagline.trimmingCharacters(in: .whitespacesAndNewlines),
            category: state.category,
            keywords: list(state.keywords),
            platforms: list(state.platforms),
            license: state.license,
            credit: name.isEmpty && link.isEmpty ? nil : ListingCredit(designer: name, url: link.isEmpty ? nil : link),
            fields: saved?.fields ?? [],
            edited: saved?.edited ?? [])
    }

    /// "swift, cli , ,json" → ["swift", "cli", "json"].
    static func list(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Whether the fields differ from the listing they were loaded from.
    static func isDirty(_ state: Listing.Center.State) -> Bool {
        guard let base = state.base else { return false }
        return !changedKeys(listing(state, saved: base), from: base).isEmpty
    }

    /// The keys the person changed: the fields against the listing they were loaded from.
    static func changedKeys(_ draft: AgentListing, from base: AgentListing) -> Swift.Set<ListingKey> {
        var keys = Swift.Set<ListingKey>()
        if draft.name != base.name { keys.insert(.name) }
        if draft.word != base.word { keys.insert(.word) }
        if draft.tagline != base.tagline { keys.insert(.tagline) }
        if draft.category != base.category { keys.insert(.category) }
        if draft.keywords != base.keywords { keys.insert(.keywords) }
        if draft.platforms != base.platforms { keys.insert(.platforms) }
        if draft.license != base.license { keys.insert(.license) }
        if draft.credit != base.credit { keys.insert(.credit) }
        return keys
    }

    /// What Save writes: the listing on disk now (the forge may have suggested more since the form loaded), with the
    /// keys the person changed taken from the form and marked `edited`.
    static func saving(_ state: Listing.Center.State, onto saved: AgentListing) -> AgentListing {
        guard let base = state.base else { return saved }
        let draft = listing(state, saved: base)
        var result = saved
        for key in changedKeys(draft, from: base) {
            switch key {
            case .name: result.name = draft.name
            case .word: result.word = draft.word
            case .tagline: result.tagline = draft.tagline
            case .category: result.category = draft.category
            case .keywords: result.keywords = draft.keywords
            case .platforms: result.platforms = draft.platforms
            case .license: result.license = draft.license
            case .credit: result.credit = draft.credit
            case .icon: break
            }
            result.edited.insert(key)
        }
        return result
    }

    /// The store's rules, by field.
    static func problems(_ listing: AgentListing, role: CraftedRole) -> [ListingKey: [String]] {
        Dictionary(grouping: ListingRules.problems(listing, role: role), by: \.key).mapValues { $0.map(\.message) }
    }
}
