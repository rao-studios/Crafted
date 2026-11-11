//  WHAT: What a designer declared in their own files: colours and faces in CSS custom properties and rules, in design
//        token JSON, and in an SVG's fills, strokes and font-family. A declared value is the designer's word, and
//        reconcile trusts it over anything measured or seen.
//  OUT:  DesignMeasures (the palette takes declared hexes exactly), reconcile (roles named by a variable's name).

import Foundation

public struct DeclaredStyle: Codable, Sendable, Equatable {
    public struct Colour: Codable, Sendable, Equatable {
        public var hex: String
        /// The name it was declared under: "--color-accent", "colors.ink".
        public var name: String
        /// The role its name says, when it says one.
        public var role: String?
        public var source: String
    }

    public struct Face: Codable, Sendable, Equatable {
        public var family: String
        public var name: String
        /// display, heading, body, caption, label, numeral.
        public var role: String?
        public var source: String
    }

    public var colours: [Colour] = []
    public var faces: [Face] = []

    public init() {}

    /// Everything declared in `files` (relative to `folder`).
    public static func read(_ files: [String], folder: URL) -> DeclaredStyle {
        var declared = DeclaredStyle()
        for file in files {
            guard let text = try? String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8) else { continue }
            switch (file as NSString).pathExtension.lowercased() {
            case "json": declared.tokens(text, source: file)
            case "svg": declared.svg(text, source: file)
            default: declared.css(text, source: file)
            }
        }
        return declared
    }

    mutating func css(_ text: String, source: String) {
        // `--name: value;` and `property: value;`: a hex in the value is a colour, a family list a face.
        for match in Self.matches(#"(--?[A-Za-z0-9_-]+|[a-z-]+)\s*:\s*([^;{}]+);"#, in: text) {
            let (name, value) = (match[1], match[2])
            if name.contains("font-family") || name.hasPrefix("--font") || name.hasPrefix("--type") || name.hasPrefix("--family") {
                if let family = Self.firstFamily(value) { add(face: family, name: name, source: source) }
            } else if let hex = Self.hexes(in: value).first {
                add(colour: hex, name: name, source: source)
            }
        }
    }

    mutating func tokens(_ text: String, source: String) {
        guard let data = text.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) else { return }
        func walk(_ value: Any, _ path: [String]) {
            if let object = value as? [String: Any] {
                // A W3C design token: {"$value": …, "$type": "color"}.
                if let leaf = object["$value"] ?? object["value"], !(leaf is [String: Any]) { walk(leaf, path); return }
                for key in object.keys.sorted() { walk(object[key]!, path + [key]) }
            } else if let text = value as? String {
                let name = path.joined(separator: ".")
                if let hex = Self.hexes(in: text).first, text.trimmingCharacters(in: .whitespaces).count <= 9 {
                    add(colour: hex, name: name, source: source)
                } else if name.lowercased().contains("font"), let family = Self.firstFamily(text) {
                    add(face: family, name: name, source: source)
                }
            }
        }
        walk(json, [])
    }

    mutating func svg(_ text: String, source: String) {
        for match in Self.matches(#"(fill|stroke|stop-color)\s*[=:]\s*["']?(#[0-9A-Fa-f]{3,6})\b"#, in: text) {
            add(colour: match[2], name: match[1], source: source)
        }
        for match in Self.matches(#"font-family\s*[=:]\s*["']?([^"';>]+)"#, in: text) {
            if let family = Self.firstFamily(match[1]) { add(face: family, name: "font-family", source: source) }
        }
    }

    mutating func add(colour hex: String, name: String, source: String) {
        guard let normal = OKLab.normal(hex), !colours.contains(where: { $0.hex == normal && $0.name == name }) else { return }
        colours.append(Colour(hex: normal, name: name, role: Self.colourRole(name), source: source))
    }

    mutating func add(face family: String, name: String, source: String) {
        guard !faces.contains(where: { $0.family == family && $0.name == name }) else { return }
        faces.append(Face(family: family, name: name, role: Self.faceRole(name), source: source))
    }

    /// The role a colour's name says.
    static func colourRole(_ name: String) -> String? {
        let n = name.lowercased()
        let table: [(String, [String])] = [
            ("inkMuted", ["muted", "subtle", "secondary-text", "text-2", "grey", "gray"]),
            ("accentInk", ["on-accent", "accent-ink", "on-primary"]),
            ("background", ["background", "-bg", "bg-", "paper", "ground", "canvas", "page"]),
            ("surface", ["surface", "card", "panel"]),
            ("rule", ["rule", "border", "line", "divider", "stroke"]),
            ("accent", ["accent", "primary", "brand", "highlight", "signal"]),
            ("secondary", ["secondary", "support", "tertiary"]),
            ("ink", ["ink", "text", "foreground", "-fg", "body", "copy"]),
        ]
        if n == "fill" || n == "stroke" || n == "stop-color" { return nil }
        if n == "--bg" || n.hasSuffix(".bg") { return "background" }
        return table.first { $0.1.contains(where: n.contains) }?.0
    }

    /// The role a face's name says.
    static func faceRole(_ name: String) -> String? {
        let n = name.lowercased()
        let table: [(String, [String])] = [
            ("display", ["display", "headline", "title", "hero", "h1"]),
            ("heading", ["heading", "subhead", "h2", "h3", "serif-accent", "quote"]),
            ("label", ["label", "mono", "code", "eyebrow", "kicker"]),
            ("caption", ["caption", "small", "footnote"]),
            ("numeral", ["numeral", "number", "figure"]),
            ("body", ["body", "text", "copy", "base", "sans", "serif"]),
        ]
        return table.first { $0.1.contains(where: n.contains) }?.0
    }

    /// The first family of a CSS font-family list that is not a generic.
    static func firstFamily(_ value: String) -> String? {
        let generics: Set<String> = ["serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui", "inherit", "initial", "ui-serif", "ui-sans-serif", "ui-monospace"]
        for part in value.split(separator: ",") {
            let family = part.trimmingCharacters(in: CharacterSet(charactersIn: "\"' \t\n!")).replacingOccurrences(of: "important", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !family.isEmpty, !generics.contains(family.lowercased()), !family.hasPrefix("var("), family.count <= 64 { return family }
        }
        return nil
    }

    static func hexes(in text: String) -> [String] {
        matches(#"#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})\b"#, in: text).map { "#" + $0[1] }
    }

    static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { i in
                let range = match.range(at: i)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }
}
