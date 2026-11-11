import Foundation

/// JavaScript and TypeScript: `require("./x")` and `import … from "./x"` resolved to files of the project; functions,
/// arrow constants, classes and exports; fs, fetch and http, child_process, console, process.argv, Math.random, Date,
/// process.env.
struct ScriptRules: LanguageRules {
    static let extensions = ["", ".js", ".ts", ".mjs", ".cjs", ".jsx", ".tsx", ".json", "/index.js", "/index.ts"]

    func imports(_ lines: [String], path: String, paths: Swift.Set<String>) -> [String] {
        let folder = (path as NSString).deletingLastPathComponent
        let specifiers = captures(lines, #"require\(\s*['"]([^'"]+)['"]\s*\)"#)
            + captures(lines, #"^\s*import\s+(?:[^'"]*\s+from\s+)?['"]([^'"]+)['"]"#)
            + captures(lines, #"^\s*export\s+[^'"]*\s+from\s+['"]([^'"]+)['"]"#)
        var found: [String] = []
        for specifier in specifiers where specifier.hasPrefix(".") {
            let joined = (folder.isEmpty ? specifier : folder + "/" + specifier)
            let normal = Self.normalise(joined)
            if let hit = Self.extensions.map({ normal + $0 }).first(where: { paths.contains($0) }) { found.append(hit) }
        }
        return Array(Swift.Set(found)).sorted()
    }

    /// `src/../data/x` → `data/x`.
    static func normalise(_ path: String) -> String {
        var parts: [Substring] = []
        for part in path.split(separator: "/") {
            if part == "." { continue }
            if part == ".." { _ = parts.popLast(); continue }
            parts.append(part)
        }
        return parts.joined(separator: "/")
    }

    func outline(_ lines: [String]) -> [OutlineItem] {
        declarations(lines, #"^\s*(export\s+)?(default\s+)?(async\s+)?(function\s+\w+|class\s+\w+|(const|let|var)\s+\w+\s*=\s*(async\s*)?(\(|function|\w+\s*=>))|^\s*module\.exports"#)
    }

    func effects(_ lines: [String]) -> [EffectLine] {
        matches(lines, [
            (#"\bfs\.|readFileSync|writeFileSync|createReadStream"#, "file"),
            (#"\bfetch\(|\baxios\b|https?\.request|XMLHttpRequest|WebSocket"#, "network"),
            (#"child_process|\bexec\(|\bspawn\("#, "process"),
            (#"process\.argv|commander|yargs"#, "entry"),
            (#"\bdocument\.|\bwindow\.|readline"#, "ui"),
            (#"console\.(log|error|table)"#, "output"),
            (#"Math\.random|crypto\.random"#, "random"),
            (#"Date\.now|new Date\("#, "clock"),
            (#"process\.env"#, "env"),
        ])
    }
}
