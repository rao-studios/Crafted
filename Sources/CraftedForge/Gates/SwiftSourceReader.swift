//  WHAT: A package's Swift sources read for what the manifest does not say: which types its roster records name
//        (`GraniteRoster.record(MarbleAgent.self)`, or `record(worker:)`), that type's `word`, and the order the store
//        reads files in (record files first, then files named for a recorded type or the package, then the rest,
//        smallest first).
//  IN:   craft.rao.nyc app/(store)/_lib/formats/swift-package/sources.ts and index.ts `sourceOrder`, ported.
//  OUT:  StoreInspection.

import Foundation

public enum SwiftSourceReader {
    /// One Swift file as the store lists it.
    public struct Entry: Sendable, Equatable {
        public var path: String
        public var size: Int
        public init(path: String, size: Int) { self.path = path; self.size = size }
    }

    /// The types a file's roster records name; a qualified name keeps its last part.
    public static func recordTypes(_ text: String) -> [String] {
        var found: [String] = []
        let pattern = #"GraniteRoster\s*\.\s*record\s*\(\s*(?:worker\s*:\s*)?([A-Za-z_][A-Za-z0-9_.]*)\s*\.\s*self\s*\)"#
        for groups in StoreRegex.groups(pattern, in: text) {
            let name = groups[0].split(separator: ".").last.map(String.init) ?? groups[0]
            if !found.contains(name) { found.append(name) }
        }
        return found
    }

    /// Whether the file declares (or extends) the type.
    public static func declaresType(_ text: String, _ name: String) -> Bool {
        StoreRegex.test(#"\b(?:struct|class|enum|actor|extension)\s+"# + NSRegularExpression.escapedPattern(for: name) + #"\b"#, text)
    }

    /// `public static let word = "marble"`, or the computed `static var word: String { "marble" }`.
    public static func word(in text: String) -> String? {
        let pattern = #"\bstatic\s+(?:let|var)\s+word\s*(?::\s*String\s*)?(?:=\s*"([^"\\]+)"|\{\s*(?:return\s+)?"([^"\\]+)"\s*\})"#
        guard let groups = StoreRegex.groups(pattern, in: text).first else { return nil }
        return groups[0].isEmpty ? groups[1] : groups[0]
    }

    /// The order Swift files under Sources/ are worth reading in.
    public static func order(_ entries: [Entry], packageName: String?, types: [String]) -> [Entry] {
        func stem(_ path: String) -> String {
            let last = path.split(separator: "/").last.map(String.init) ?? path
            return last.hasSuffix(".swift") ? String(last.dropLast(6)) : last
        }
        func rank(_ entry: Entry) -> Int {
            let s = stem(entry.path)
            if s.hasSuffix("Record") { return 0 }
            if types.contains(s) { return 1 }
            if let packageName, s == packageName { return 2 }
            return 3
        }
        let swift = entries.filter { $0.path.hasPrefix("Sources/") && $0.path.hasSuffix(".swift") }
        return swift.sorted { a, b in
            let (ra, rb) = (rank(a), rank(b))
            if ra != rb { return ra < rb }
            if a.size != b.size { return a.size < b.size }
            return a.path.compare(b.path, locale: Locale(identifier: "en")) == .orderedAscending
        }
    }
}
