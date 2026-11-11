import Foundation

/// Swift: a module imports modules, not files, so a file's project imports are the files that declare the types it
/// names; declarations by keyword; FileManager, URLSession, Process, print, Date(), random, the environment, @main.
struct SwiftRules: LanguageRules {
    func imports(_ lines: [String], path: String, paths: Swift.Set<String>) -> [String] {
        // Types each other Swift file declares, matched against the identifiers this one uses.
        let words = Swift.Set(lines.joined(separator: " ").split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") }).map(String.init))
        return paths.filter { $0 != path && $0.hasSuffix(".swift") && words.contains(($0 as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")) }.sorted()
    }

    func outline(_ lines: [String]) -> [OutlineItem] {
        declarations(lines, #"^\s*(public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(static\s+)?(final\s+)?(func|struct|class|enum|protocol|extension|actor|init)\b"#)
    }

    func effects(_ lines: [String]) -> [EffectLine] {
        matches(lines, [
            (#"FileManager|contentsOf:|\.write\(to:"#, "file"),
            (#"URLSession|URLRequest|NWConnection"#, "network"),
            (#"\bProcess\(\)|posix_spawn"#, "process"),
            (#"@main|CommandLine\.arguments|ArgumentParser"#, "entry"),
            (#"SwiftUI|AppKit|UIKit"#, "ui"),
            (#"\bprint\("#, "output"),
            (#"\.random\(|SystemRandomNumberGenerator"#, "random"),
            (#"\bDate\(\)|Date\.now"#, "clock"),
            (#"ProcessInfo\.processInfo\.environment|getenv"#, "env"),
        ])
    }
}
