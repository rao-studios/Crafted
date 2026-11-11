//  WHAT: Assets/listing.json as the store reads it: every key optional, and each that breaks a store rule set
//        aside with a sentence saying what it must be (name 1 to 64, tagline up to 140, one of seven categories,
//        keywords `^[a-z0-9][a-z0-9 +.#-]{0,23}$` up to eight, one to eight platforms of 32 at most, an SPDX licence
//        of 64 at most, fields as `craft agents --json` gives them).
//  IN:   craft.rao.nyc app/(store)/_lib/source/listing-json.ts and listing-rules.ts (`parseFields`, `KEYWORD`), ported.
//  OUT:  StoreValidator, where every note is a problem: a package Crafted made should need none set aside.

import CraftedCore
import Foundation

public enum ListingJSONReader {
    public static let path = "Assets/listing.json"

    public struct Parsed: Sendable, Equatable {
        /// What the store would keep, by key.
        public var name: String?
        public var tagline: String?
        public var category: String?
        public var keywords: [String]?
        public var platforms: [String]?
        public var license: String?
        public var fields: [ListingField]?
        /// Each key set aside, with why.
        public var notes: [String]
        /// The keys a note was said about.
        public var flagged: Swift.Set<String>
    }

    public static func parse(_ text: String) -> Parsed {
        var parsed = Parsed(notes: [], flagged: [])
        guard let data = text.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            parsed.notes.append("\(path) isn’t valid JSON, so none of it was read.")
            return parsed
        }
        guard let raw = json as? [String: Any] else {
            parsed.notes.append("\(path) should be one JSON object.")
            return parsed
        }
        func set(_ key: String, _ why: String) {
            parsed.notes.append("“\(key)” in \(path): \(why)")
            parsed.flagged.insert(key)
        }
        if let value = raw["name"] {
            let name = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty, name.count <= ListingRules.nameLimit { parsed.name = name }
            else { set("name", "text, 1 to \(ListingRules.nameLimit) characters.") }
        }
        if let value = raw["tagline"] {
            if let tagline = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), tagline.count <= ListingRules.taglineLimit {
                parsed.tagline = tagline
            } else { set("tagline", "text, up to \(ListingRules.taglineLimit) characters.") }
        }
        if let value = raw["category"] {
            if let category = value as? String, ListingCategory(rawValue: category) != nil { parsed.category = category }
            else { set("category", "one of graphics, developer, productivity, data, media, writing, utilities.") }
        }
        if let value = raw["keywords"] {
            if let list = value as? [Any], list.allSatisfy({ $0 is String }) {
                var all: [String] = []
                for keyword in list.compactMap({ $0 as? String }) {
                    let cleaned = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    if !cleaned.isEmpty, !all.contains(cleaned) { all.append(cleaned) }
                }
                let good = all.filter(ListingRules.isKeyword)
                if good.count < all.count { set("keywords", "\(all.count - good.count) set aside: words or short phrases, up to 24 letters each.") }
                if good.count > ListingRules.keywordLimit { set("keywords", "only the first \(ListingRules.keywordLimit) are kept.") }
                parsed.keywords = Array(good.prefix(ListingRules.keywordLimit))
            } else { set("keywords", "a list of words.") }
        }
        if let value = raw["platforms"] {
            let list: [Any]? = (value as? [Any]) ?? (value as? String).map { $0.split(separator: ",").map(String.init) }
            let platforms = list.flatMap { items in
                items.allSatisfy({ $0 is String })
                    ? items.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }.filter { !$0.isEmpty }
                    : nil
            }
            if let platforms, (1...ListingRules.platformLimit).contains(platforms.count), platforms.allSatisfy({ $0.count <= 32 }) {
                parsed.platforms = platforms
            } else { set("platforms", "one to eight, such as \"macOS 14\".") }
        }
        if let value = raw["license"] {
            let license = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !license.isEmpty, license.count <= 64 { parsed.license = license }
            else { set("license", "an SPDX name, such as MIT.") }
        }
        if let value = raw["fields"] {
            switch fields(value) {
            case .success(let fields): parsed.fields = fields
            case .failure(let why): set("fields", why.message)
            }
        }
        if raw["description"] != nil { set("description", "README.md is the description now; this key is not read.") }
        if raw["icon_url"] != nil { set("icon_url", "the icon is Assets/icon.png now; this key is not read.") }
        return parsed
    }

    struct FieldProblem: Error { let message: String }

    /// The fields block: an array of {name, type, required, note?}, or an entry holding one.
    static func fields(_ value: Any) -> Result<[ListingField], FieldProblem> {
        var json = value
        if let object = json as? [String: Any], let inner = object["fields"] as? [Any] { json = inner }
        guard let list = json as? [Any] else { return .failure(FieldProblem(message: "Fields are a JSON array.")) }
        var fields: [ListingField] = []
        for (index, item) in list.enumerated() {
            guard let field = item as? [String: Any] else { return .failure(FieldProblem(message: "Field \(index + 1) is not an object.")) }
            guard let name = field["name"] as? String, StoreRegex.whole("[A-Za-z_][A-Za-z0-9_]{0,63}", name) else {
                return .failure(FieldProblem(message: "Field \(index + 1) needs a name, a Swift identifier."))
            }
            guard let type = field["type"] as? String, (1...256).contains(type.count) else {
                return .failure(FieldProblem(message: "“\(name)” needs a type."))
            }
            guard let flag = field["required"] as? NSNumber, CFGetTypeID(flag) == CFBooleanGetTypeID() else {
                return .failure(FieldProblem(message: "“\(name)” needs \"required\": true or false."))
            }
            let required = flag.boolValue
            let note = field["note"]
            if let note, !(note is NSNull), !(note is String) { return .failure(FieldProblem(message: "“\(name)”: a note is text.")) }
            fields.append(ListingField(name: name, type: type, required: required, note: note as? String ?? ""))
        }
        return .success(fields)
    }
}
