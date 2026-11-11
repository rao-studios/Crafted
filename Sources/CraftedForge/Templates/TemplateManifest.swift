//  WHAT: A template's template.json: which strings in it are its identity (so the assembler can stamp a new one),
//        what never ships, and which folders hold model-written bodies that are never stamped.
//
//        {"format": "crafted-template/1", "kind": "engineer",
//         "tokens": {"word": "skeletonword", "display": "Skeleton Template", "base": "Skeleton", "lowerBase": "skeleton"},
//         "skip": [".build", ".swiftpm", "template.json"],
//         "verbatim": ["Sources/SkeletonCore/Logic", "Sources/SkeletonCore/Resources"]}
//
//  PIN:  TOKENS ARE THE TEMPLATE'S REAL NAMES. A template is a package that builds and tests as it stands
//        (SkeletonAgent, SkeletonCore, `static let word = "skeletonword"`); stamping replaces, longest first, the
//        word, then the display name, then the base, then the lower-camel base, in every text file and every path
//        component outside `verbatim` and `skip`. A template's author keeps those strings for identity only.

import Foundation

public enum TemplateKind: String, Codable, Sendable, CaseIterable {
    case engineer = "EngineerAgentSkeleton"
    case designer = "DesignerAgentTemplate"

    public var role: String { self == .engineer ? "engineer" : "designer" }
}

public struct TemplateManifest: Codable, Sendable, Equatable {
    public struct Tokens: Codable, Sendable, Equatable {
        public var word: String
        public var display: String
        public var base: String
        public var lowerBase: String

        public init(word: String, display: String, base: String, lowerBase: String) {
            self.word = word; self.display = display; self.base = base; self.lowerBase = lowerBase
        }
    }

    public var format: String
    public var kind: String
    public var tokens: Tokens
    /// Path prefixes, relative to the template, that are never copied.
    public var skip: [String]
    /// Path prefixes copied (or overlaid) as they are: model-written bodies, binary resources.
    public var verbatim: [String]

    public init(format: String = "crafted-template/1", kind: String, tokens: Tokens, skip: [String], verbatim: [String]) {
        self.format = format; self.kind = kind; self.tokens = tokens; self.skip = skip; self.verbatim = verbatim
    }

    public static func read(_ template: URL) throws -> TemplateManifest {
        let url = template.appendingPathComponent("template.json")
        guard let data = try? Data(contentsOf: url) else {
            throw ForgeError.template("\(template.lastPathComponent) has no template.json")
        }
        return try JSONDecoder().decode(TemplateManifest.self, from: data)
    }

    func isSkipped(_ relative: String) -> Bool {
        let always = [".build", ".swiftpm", ".git", ".DS_Store", "template.json"]
        return (always + skip).contains { relative == $0 || relative.hasPrefix($0 + "/") }
            || relative.split(separator: "/").contains { $0 == ".build" || $0 == ".swiftpm" || $0 == ".DS_Store" }
    }

    func isVerbatim(_ relative: String) -> Bool {
        verbatim.contains { relative == $0 || relative.hasPrefix($0 + "/") }
    }
}
