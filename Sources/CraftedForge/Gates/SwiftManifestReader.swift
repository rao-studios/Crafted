//  WHAT: Package.swift read without running it, as the store reads it: the package's name, its library products,
//        its platforms, and whether it depends on Granite. A manifest that computes these (a variable for the name,
//        a loop of products) reads as having none.
//  IN:   craft.rao.nyc app/(store)/_lib/formats/swift-package/manifest.ts, ported rule for rule (2026-11-10).
//  OUT:  StoreInspection.

import Foundation

public struct SwiftManifest: Sendable, Equatable {
    public var name: String?
    public var libraries: [String]
    /// "macOS 14", "iOS 17.2".
    public var platforms: [String]
    public var dependsOnGranite: Bool

    public init(name: String?, libraries: [String], platforms: [String], dependsOnGranite: Bool) {
        self.name = name; self.libraries = libraries; self.platforms = platforms; self.dependsOnGranite = dependsOnGranite
    }
}

public enum SwiftManifestReader {
    static let platformNames = ["macOS": "macOS", "iOS": "iOS", "tvOS": "tvOS", "watchOS": "watchOS", "visionOS": "visionOS",
                                "macCatalyst": "Mac Catalyst"]

    public static func parse(_ text: String) -> SwiftManifest {
        let code = stripSwiftComments(text)
        let body: String
        if let start = code.range(of: #"\bPackage\s*\("#, options: .regularExpression) {
            body = String(code[start.lowerBound...])
        } else {
            body = code
        }
        let name = StoreRegex.groups(#"\bname\s*:\s*"([^"\\]+)""#, in: body).first?[0]
            .trimmingCharacters(in: .whitespaces)
        var libraries: [String] = []
        for groups in StoreRegex.groups(#"\.library\s*\(\s*name\s*:\s*"([^"\\]+)""#, in: body) where !libraries.contains(groups[0]) {
            libraries.append(groups[0])
        }
        var platforms: [String] = []
        let block = StoreRegex.groups(#"\bplatforms\s*:\s*\[([^\]]*)\]"#, in: body).first?[0] ?? ""
        let platform = #"\.(macOS|iOS|tvOS|watchOS|visionOS|macCatalyst)\s*\(\s*(?:\.v(\d+)(?:_(\d+))?|"(\d+)(?:\.(\d+))?(?:\.\d+)*")\s*\)"#
        for groups in StoreRegex.groups(platform, in: block) {
            let major = groups[1].isEmpty ? groups[3] : groups[1]
            let minor = groups[1].isEmpty ? groups[4] : groups[2]
            let label = "\(platformNames[groups[0]] ?? groups[0]) \(major)" + (!minor.isEmpty && minor != "0" ? ".\(minor)" : "")
            if !platforms.contains(label) { platforms.append(label) }
        }
        let locations = StoreRegex.groups(#"\.package\s*\(\s*(?:name\s*:\s*"[^"]*"\s*,\s*)?url\s*:\s*"([^"]+)""#, in: body).map { $0[0] }
            + StoreRegex.groups(#"\.package\s*\(\s*(?:name\s*:\s*"[^"]*"\s*,\s*)?path\s*:\s*"([^"]+)""#, in: body).map { $0[0] }
        return SwiftManifest(name: name?.isEmpty == false ? name : nil, libraries: libraries, platforms: platforms,
                             dependsOnGranite: locations.contains { packageIdentity($0) == "granite" })
    }

    /// SwiftPM's identity for a dependency: the last part of its URL or path, without `.git`, lowercased.
    public static func packageIdentity(_ location: String) -> String {
        var trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = trimmed.last, last == "/" || last == "\\" { trimmed.removeLast() }
        let last = trimmed.split(whereSeparator: { "/\\:".contains($0) }).last.map(String.init) ?? ""
        let stripped = last.range(of: #"\.git$"#, options: [.regularExpression, .caseInsensitive]).map { String(last[..<$0.lowerBound]) } ?? last
        return stripped.lowercased()
    }

    /// Swift with its comments taken out, strings kept whole (a URL's `//` is not a comment); block comments nest.
    /// `keepLines` keeps a block comment's line breaks, so line numbers still hold (the store's reader does not).
    public static func stripSwiftComments(_ text: String, keepLines: Bool = false) -> String {
        let c = Array(text)
        var out = ""
        var i = 0
        func starts(_ s: String, at index: Int) -> Bool {
            let chars = Array(s)
            guard index + chars.count <= c.count else { return false }
            return Array(c[index..<(index + chars.count)]) == chars
        }
        while i < c.count {
            let next: Character? = i + 1 < c.count ? c[i + 1] : nil
            if c[i] == "\"" {
                let close = starts("\"\"\"", at: i) ? "\"\"\"" : "\""
                var j = i + close.count
                while j < c.count && !starts(close, at: j) { j += c[j] == "\\" ? 2 : 1 }
                let end = min(j + close.count, c.count)
                out += String(c[i..<end])
                i = j + close.count
            } else if c[i] == "/" && next == "/" {
                while i < c.count && c[i] != "\n" { i += 1 }
            } else if c[i] == "/" && next == "*" {
                var depth = 0
                let opened = i
                while i < c.count {
                    if starts("/*", at: i) {
                        depth += 1; i += 2
                    } else if starts("*/", at: i) {
                        depth -= 1; i += 2
                        if depth == 0 { break }
                    } else {
                        i += 1
                    }
                }
                out += " "
                if keepLines { out += String(repeating: "\n", count: c[opened..<min(i, c.count)].filter { $0 == "\n" }.count) }
            } else {
                out.append(c[i])
                i += 1
            }
        }
        return out
    }
}
