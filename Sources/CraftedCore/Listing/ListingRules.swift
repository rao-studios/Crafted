//  WHAT: The store's rules for a listing, as sentences beside the field they belong to. The form shows them inline
//        and keeps Download off until there are none.
//  IN:   craft.rao.nyc app/(store)/_lib/source/listing-json.ts and listing-rules.ts (2026-11-10): name ≤ 64,
//        tagline ≤ 140, the seven categories, ≤ 8 keywords each `^[a-z0-9][a-z0-9 +.#-]{0,23}$`, 1 to 8 platforms,
//        an SPDX licence; the word rule from AgentNameRules.
//  OUT:  The listing form, the forge's assembly gate.

import Foundation

public struct ListingProblem: Equatable, Sendable, Hashable {
    public var key: ListingKey
    public var message: String

    public init(_ key: ListingKey, _ message: String) {
        self.key = key
        self.message = message
    }
}

public enum ListingRules {
    public static let nameLimit = 64
    public static let taglineLimit = 140
    public static let keywordLimit = 8
    public static let platformLimit = 8

    public static func problems(_ listing: AgentListing, role: CraftedRole) -> [ListingProblem] {
        var problems: [ListingProblem] = []
        let name = listing.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { problems.append(ListingProblem(.name, "Give the agent a name.")) }
        if name.count > nameLimit { problems.append(ListingProblem(.name, "A name is \(nameLimit) characters at most.")) }
        if let problem = AgentNameRules.wordProblem(listing.word) { problems.append(ListingProblem(.word, problem)) }
        let tagline = listing.tagline.trimmingCharacters(in: .whitespacesAndNewlines)
        if tagline.isEmpty { problems.append(ListingProblem(.tagline, "Say in a line what it makes.")) }
        if tagline.count > taglineLimit {
            problems.append(ListingProblem(.tagline, "A tagline is \(taglineLimit) characters at most."))
        }
        if listing.keywords.count > keywordLimit {
            problems.append(ListingProblem(.keywords, "Up to \(keywordLimit) keywords."))
        }
        for keyword in listing.keywords where !isKeyword(keyword) {
            problems.append(ListingProblem(.keywords, "\"\(keyword)\" is not a keyword the store takes: lowercase letters, digits, spaces and + . # -, 24 characters at most."))
        }
        if listing.platforms.isEmpty || listing.platforms.count > platformLimit {
            problems.append(ListingProblem(.platforms, "Name 1 to \(platformLimit) platforms."))
        }
        if role == .designer {
            let designer = listing.credit?.designer.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if designer.isEmpty { problems.append(ListingProblem(.credit, "A style agent credits its designer: give your name.")) }
        }
        if let url = listing.credit?.url, !url.isEmpty, URL(string: url)?.scheme?.hasPrefix("http") != true {
            problems.append(ListingProblem(.credit, "The credit link starts with https://."))
        }
        return problems
    }

    /// `^[a-z0-9][a-z0-9 +.#-]{0,23}$`
    public static func isKeyword(_ keyword: String) -> Bool {
        guard let first = keyword.first, keyword.count <= 24 else { return false }
        func allowed(_ c: Character, first: Bool) -> Bool {
            guard c.isASCII else { return false }
            if (c.isLetter && c.isLowercase) || c.isNumber { return true }
            return !first && " +.#-".contains(c)
        }
        return allowed(first, first: true) && keyword.dropFirst().allSatisfy { allowed($0, first: false) }
    }

    /// A keyword as the store would take it, or nil: lowercased, stray characters dropped, cut to 24.
    public static func keyword(from text: String) -> String? {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespaces)
        var kept = String(lowered.filter { $0.isASCII && ($0.isLetter || $0.isNumber || " +.#-".contains($0)) }.prefix(24))
        while let first = kept.first, !(first.isLetter || first.isNumber) { kept.removeFirst() }
        return kept.isEmpty ? nil : kept
    }
}
