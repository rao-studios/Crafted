//  WHAT: The store listing of a generated agent, as the person edits it in the listing form, and as the package
//        carries it in Assets/listing.json.
//  IN:   The forge's suggestion (name, tagline, category, keywords, fields), the person's edits.
//  OUT:  Generations/<id>/listing.json (with `edited`), the package's Assets/listing.json (`storeJSON`), the form.
//  PIN:  THE PERSON'S WORDS WIN. Every key a person changed is in `edited`; a suggestion from the forge fills only
//        keys not in it (`merging(suggestion:)`), so a run that finishes after the form was filled never undoes it.

import Foundation

public enum ListingKey: String, Codable, Sendable, CaseIterable {
    case name, word, tagline, category, keywords, platforms, license, credit, icon
}

/// The store's seven categories (listing-json.ts). There is no "games".
public enum ListingCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case graphics, developer, productivity, data, media, writing, utilities
    public var id: String { rawValue }
    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// The licences the store recognises in a LICENSE file.
public enum ListingLicence: String, Codable, Sendable, CaseIterable, Identifiable {
    case mit = "MIT"
    case apache2 = "Apache-2.0"
    case mpl2 = "MPL-2.0"
    case gpl3 = "GPL-3.0"
    case bsd2 = "BSD-2-Clause"
    case bsd3 = "BSD-3-Clause"
    case isc = "ISC"
    public var id: String { rawValue }
    /// Copyleft: a port of a project under it stays under it.
    public var isCopyleft: Bool { self == .gpl3 || self == .mpl2 }
}

/// One input of the agent, as the store shows it. Read-only in the form: it comes from the agent.
public struct ListingField: Codable, Sendable, Equatable, Hashable {
    public var name: String
    public var type: String
    public var required: Bool
    public var note: String

    public init(name: String, type: String, required: Bool, note: String) {
        self.name = name; self.type = type; self.required = required; self.note = note
    }
}

/// Who a designer agent's style belongs to. The store ignores unknown keys today; the key is forward-compatible.
public struct ListingCredit: Codable, Sendable, Equatable, Hashable {
    public var designer: String
    public var url: String?

    public init(designer: String, url: String? = nil) {
        self.designer = designer
        self.url = url
    }
}

public struct AgentListing: Codable, Sendable, Equatable {
    public var name: String
    public var word: String
    public var tagline: String
    public var category: ListingCategory
    public var keywords: [String]
    public var platforms: [String]
    public var license: ListingLicence
    public var credit: ListingCredit?
    public var fields: [ListingField]
    /// Keys the person changed; a suggestion never overwrites them.
    public var edited: Swift.Set<ListingKey>

    public init(name: String, word: String, tagline: String = "", category: ListingCategory = .utilities,
                keywords: [String] = [], platforms: [String] = ["macOS 26"], license: ListingLicence = .mit,
                credit: ListingCredit? = nil, fields: [ListingField] = [], edited: Swift.Set<ListingKey> = []) {
        self.name = name; self.word = word; self.tagline = tagline; self.category = category; self.keywords = keywords
        self.platforms = platforms; self.license = license; self.credit = credit; self.fields = fields; self.edited = edited
    }

    /// A first listing for a dropped folder, before the forge has said anything.
    public static func placeholder(folderName: String, role: CraftedRole, credit: String?) -> AgentListing {
        let identity = AgentIdentity.derive(display: folderName)
        return AgentListing(
            name: identity.display, word: identity.word,
            category: role == .designer ? .graphics : .utilities,
            credit: role == .designer ? credit.map { ListingCredit(designer: $0) } : nil
        )
    }

    /// The identity the package is assembled with.
    public var identity: AgentIdentity { AgentIdentity.derive(display: name, word: word) }

    /// This listing with a suggestion's values in every key the person has not edited. Fields always follow the agent.
    public func merging(suggestion: AgentListing) -> AgentListing {
        var merged = self
        if !edited.contains(.name) { merged.name = suggestion.name }
        if !edited.contains(.word) { merged.word = suggestion.word }
        if !edited.contains(.tagline) { merged.tagline = suggestion.tagline }
        if !edited.contains(.category) { merged.category = suggestion.category }
        if !edited.contains(.keywords) { merged.keywords = suggestion.keywords }
        if !edited.contains(.platforms) { merged.platforms = suggestion.platforms }
        if !edited.contains(.license) { merged.license = suggestion.license }
        if !edited.contains(.credit), suggestion.credit != nil { merged.credit = suggestion.credit }
        merged.fields = suggestion.fields
        return merged
    }

    /// Assets/listing.json, as the store reads it (listing-json.ts): no `word` (the store reads it from the Swift
    /// source) and no `edited`.
    public func storeJSON() throws -> Data {
        struct Store: Encodable {
            var name: String
            var tagline: String
            var category: String
            var keywords: [String]
            var platforms: [String]
            var license: String
            var fields: [ListingField]
            var credit: ListingCredit?
        }
        let store = Store(name: name, tagline: tagline, category: category.rawValue, keywords: keywords,
                          platforms: platforms, license: license.rawValue, fields: fields, credit: credit)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(store)
    }
}
