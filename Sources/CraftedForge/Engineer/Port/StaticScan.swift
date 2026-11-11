//  WHAT: The first rung, before anything compiles: a port's file imports only what its target allows, reaches no file,
//        network, process or environment, holds no secret, is not a stub, and declares what its contract names.
//  PIN:  A GENERATED AGENT MAKES NO NETWORK CALLS AND RUNS NO PROCESSES. Said in the prompt, enforced here, and by
//        structure: the logic target cannot reach the files or the agent target.

import Foundation

public enum StaticScan {
    /// Imports each kind of file may make.
    static let allowedImports: [PortTaskKind: Swift.Set<String>] = [
        .unit: ["Foundation"],
        .handler: ["Foundation", "GraniteAgents"],
    ]

    static let forbidden: [(String, String)] = [
        (#"\bProcess\s*\("#, "runs a process"), (#"\bNSTask\b"#, "runs a process"), (#"\bposix_spawn|\bpopen\(|\bsystem\("#, "runs a process"),
        (#"\bURLSession\b|\bURLRequest\b|\bNWConnection\b|\bCFNetwork\b|\bCFSocket\b"#, "reaches the network"),
        (#"\bFileManager\b|\bfopen\(|contentsOf\s*:|\.write\s*\(\s*to\s*:|\bFileHandle\b"#, "reaches files outside the kit"),
        (#"ProcessInfo\.processInfo\.environment|\bgetenv\("#, "reads the environment"),
        (#"Bundle\.module"#, "uses Bundle.module (use CoreResources)"),
        (#"@_silgen_name|\bdlopen\(|\bdlsym\("#, "loads code at run time"),
        (#"\bprint\s*\("#, "prints (stdout is the wire's; return products or say notes)"),
    ]

    public static func problems(_ text: String, kind: PortTaskKind, declares: String) -> [String] {
        var problems: [String] = []
        if text.hasPrefix(SwiftText.stubMarker) { problems.append("the file is a stub") }
        let allowed = allowedImports[kind] ?? ["Foundation"]
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("import ") || trimmed.hasPrefix("@testable import") || trimmed.hasPrefix("@_exported import") else { continue }
            let module = trimmed.split(separator: " ").last.map(String.init) ?? ""
            if !allowed.contains(module) || trimmed.hasPrefix("@") {
                problems.append("it imports \(module): a \(kind.rawValue) imports " + allowed.sorted().joined(separator: " and ") + " only")
            }
        }
        let code = stripped(text)
        for (pattern, why) in forbidden where code.range(of: pattern, options: .regularExpression) != nil {
            problems.append("it \(why)")
        }
        if code.range(of: #"\b(enum|struct)\s+"# + declares + #"\b"#, options: .regularExpression) == nil {
            problems.append("it does not declare \(declares)")
        }
        let secrets = SecretScan.findings(in: text, path: nil)
        if !secrets.isEmpty { problems.append("it holds what looks like a secret: write no keys, tokens or passwords") }
        return Array(NSOrderedSet(array: problems)) as? [String] ?? problems
    }

    /// `text` without comments and string literals, so a word in a sentence is not mistaken for code.
    static func stripped(_ text: String) -> String {
        var out = ""
        var index = text.startIndex
        while index < text.endIndex {
            let rest = text[index...]
            if rest.hasPrefix("//") {
                index = text[index...].firstIndex(of: "\n") ?? text.endIndex
            } else if rest.hasPrefix("/*") {
                index = text.range(of: "*/", range: index..<text.endIndex)?.upperBound ?? text.endIndex
            } else if rest.hasPrefix("\"") {
                let triple = rest.hasPrefix("\"\"\"")
                var cursor = text.index(index, offsetBy: triple ? 3 : 1)
                while cursor < text.endIndex {
                    if text[cursor] == "\\" { cursor = text.index(cursor, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex; continue }
                    if triple ? text[cursor...].hasPrefix("\"\"\"") : text[cursor] == "\"" { break }
                    if !triple && text[cursor] == "\n" { break }
                    cursor = text.index(after: cursor)
                }
                index = cursor < text.endIndex ? text.index(cursor, offsetBy: triple ? 3 : 1, limitedBy: text.endIndex) ?? text.endIndex : text.endIndex
                out += "\"\""
            } else {
                out.append(text[index])
                index = text.index(after: index)
            }
        }
        return out
    }
}
