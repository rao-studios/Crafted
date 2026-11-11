import Foundation
import GraniteAgents

/// Where a call's files go: the call's `output` folder (relative to the project), else a folder named for the agent's
/// word; each file named from its product's name, a name taken once per call.
struct FilePlace: Sendable {
    let directory: URL
    /// Relative to the project: `skeletonword` when the call names none.
    let folder: String
    private(set) var taken: Set<String> = []

    init(directory: URL, output: String?, word: String) throws {
        self.directory = directory
        let given = output?.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) ?? ""
        let folder = given.isEmpty ? word : given
        _ = try CommandKit.confined(folder, in: directory)
        self.folder = folder
    }

    /// A relative path for a product called `name` with `suffix` (".png", ".timeseries.json"), unique in the call.
    mutating func path(_ name: String, suffix: String) -> String {
        let stem = Self.slug(name)
        var candidate = "\(folder)/\(stem)\(suffix)"
        var count = 2
        while taken.contains(candidate) {
            candidate = "\(folder)/\(stem)-\(count)\(suffix)"
            count += 1
        }
        taken.insert(candidate)
        return candidate
    }

    /// "Monthly totals (2026)" → "monthly-totals-2026".
    static func slug(_ name: String) -> String {
        let lowered = name.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        var slug = ""
        for character in lowered {
            if character.isASCII && (character.isLetter || character.isNumber) { slug.append(character) }
            else if !slug.isEmpty && !slug.hasSuffix("-") { slug.append("-") }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        return slug.isEmpty ? "result" : String(slug.prefix(60))
    }
}
