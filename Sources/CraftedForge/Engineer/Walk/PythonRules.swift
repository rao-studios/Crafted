import Foundation

/// Python: `import a.b`, `from .c import d` resolved to files of the project; `def`, `class` and top-level constants;
/// open, requests and urllib, subprocess, print and input, random, the clock, os.environ, argparse and `__main__`.
struct PythonRules: LanguageRules {
    func imports(_ lines: [String], path: String, paths: Swift.Set<String>) -> [String] {
        let folder = (path as NSString).deletingLastPathComponent
        var found: [String] = []
        for module in captures(lines, #"^\s*from\s+([\w.]+)\s+import"#) + captures(lines, #"^\s*import\s+([\w.]+)"#) {
            var base = folder
            var name = module
            if module.hasPrefix(".") {
                let dots = module.prefix(while: { $0 == "." }).count
                for _ in 1..<max(dots, 1) { base = (base as NSString).deletingLastPathComponent }
                name = String(module.dropFirst(dots))
            } else {
                base = ""
            }
            let relative = name.replacingOccurrences(of: ".", with: "/")
            let stem = [base, relative].filter { !$0.isEmpty }.joined(separator: "/")
            for candidate in [stem + ".py", stem + "/__init__.py"] where paths.contains(candidate) {
                found.append(candidate)
                break
            }
        }
        return Array(Swift.Set(found)).sorted()
    }

    func outline(_ lines: [String]) -> [OutlineItem] {
        declarations(lines, #"^(\s*(async\s+)?def\s+\w+|\s*class\s+\w+|[A-Z_][A-Z0-9_]*\s*=)"#)
    }

    func effects(_ lines: [String]) -> [EffectLine] {
        matches(lines, [
            (#"\bopen\(|Path\(.*\)\.(read|write)|shutil\."#, "file"),
            (#"\b(requests|urllib|http\.client|httpx|aiohttp|socket)\b"#, "network"),
            (#"\b(subprocess|os\.system|os\.popen)\b"#, "process"),
            (#"\bargparse\b|__name__\s*==\s*['"]__main__['"]|sys\.argv"#, "entry"),
            (#"\binput\(|tkinter|curses"#, "ui"),
            (#"\bprint\("#, "output"),
            (#"\brandom\.|secrets\."#, "random"),
            (#"datetime\.now|time\.time\(|date\.today"#, "clock"),
            (#"os\.environ|getenv"#, "env"),
        ])
    }
}
