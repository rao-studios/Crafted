import Foundation

/// Any other language, by line heuristics: declarations by common keywords, effects by common names, no imports.
struct GenericRules: LanguageRules {
    func imports(_ lines: [String], path: String, paths: Swift.Set<String>) -> [String] { [] }

    func outline(_ lines: [String]) -> [OutlineItem] {
        declarations(lines, #"^\s*(pub\s+|public\s+|private\s+|static\s+|export\s+)*(func|fn|def|function|sub|class|struct|interface|trait|impl|module|type)\s+\w+"#)
    }

    func effects(_ lines: [String]) -> [EffectLine] {
        matches(lines, [
            (#"(?i)\b(open|fopen|readfile|writefile|os\.Create|File\.)"#, "file"),
            (#"(?i)\b(http|socket|fetch|request)\b"#, "network"),
            (#"(?i)\b(exec|spawn|system|popen)\("#, "process"),
            (#"(?i)\b(main|argv|args)\b"#, "entry"),
            (#"(?i)\b(print|println|printf|puts|echo)\b"#, "output"),
            (#"(?i)\brand(om)?\b"#, "random"),
            (#"(?i)\b(now|time\(\))"#, "clock"),
            (#"(?i)\b(getenv|environ|ENV\[)"#, "env"),
        ])
    }
}
