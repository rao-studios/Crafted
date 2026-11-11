import Foundation

/// A source file's language, by its extension. Swift, Python and JavaScript/TypeScript have import, outline and
/// effect rules of their own; the rest are read with line heuristics.
public enum SourceLanguage: String, Codable, Sendable, CaseIterable {
    case swift, python, javascript, typescript
    case go, rust, ruby, java, kotlin, csharp, php, c, cpp, objc, shell, lua, r, scala, elixir, dart, other

    static let byExtension: [String: SourceLanguage] = [
        "swift": .swift, "py": .python, "js": .javascript, "mjs": .javascript, "cjs": .javascript, "jsx": .javascript,
        "ts": .typescript, "tsx": .typescript, "mts": .typescript, "go": .go, "rs": .rust, "rb": .ruby, "java": .java,
        "kt": .kotlin, "kts": .kotlin, "cs": .csharp, "php": .php, "c": .c, "h": .c, "cc": .cpp, "cpp": .cpp, "hpp": .cpp,
        "cxx": .cpp, "m": .objc, "mm": .objc, "sh": .shell, "bash": .shell, "zsh": .shell, "lua": .lua, "r": .r,
        "scala": .scala, "ex": .elixir, "exs": .elixir, "dart": .dart,
    ]

    /// The language of a path, or nil when it is not source code.
    public static func of(_ path: String) -> SourceLanguage? {
        byExtension[(path as NSString).pathExtension.lowercased()]
    }

    /// The rules the walk reads this language with.
    var rules: any LanguageRules {
        switch self {
        case .swift: return SwiftRules()
        case .python: return PythonRules()
        case .javascript, .typescript: return ScriptRules()
        default: return GenericRules()
        }
    }
}
