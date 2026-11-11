//  WHAT: What a generated agent may not do, found in its Swift before it is compiled: reach the network, start a
//        process, load code, or import a module outside its target's allowlist (a Core target imports Foundation
//        only). Each hit names file and line.
//  IN:   A model-written body (a domain type, a logic unit, a handler) and the imports its target allows.
//  OUT:  The engineer port loop, before a candidate climbs the ladder; a hit sends it back with the sentence.
//  PIN:  STRUCTURE FIRST, THIS SECOND. Core cannot reach files or the agent target by construction; this catches the
//        rest in the text, so a body that would phone home never builds.

import Foundation

public enum CapabilityScan {
    /// Imports a Core target may use.
    public static let coreImports: Swift.Set<String> = ["Foundation"]

    /// Each forbidden capability and each import outside `allowedImports` in `text`.
    public static func hits(in text: String, path: String?, allowedImports: Swift.Set<String>? = nil) -> [ScanHit] {
        let code = stripped(text)
        let ns = code as NSString
        guard ns.length > 0 else { return [] }
        let lines = LineIndex(ns)
        var hits: [ScanHit] = []
        for (regex, what) in forbidden {
            for match in regex.matches(in: code, range: NSRange(location: 0, length: ns.length)) {
                hits.append(ScanHit(what: what, path: path, line: lines.line(at: match.range.location), kind: .info, range: match.range))
            }
        }
        if let allowedImports {
            for match in importLine.matches(in: code, range: NSRange(location: 0, length: ns.length)) {
                let module = ns.substring(with: match.range(at: 1))
                guard !allowedImports.contains(module) else { continue }
                hits.append(ScanHit(what: "an import of \(module), which this target may not use", path: path,
                                    line: lines.line(at: match.range.location), kind: .info, range: match.range))
            }
        }
        return hits.sorted { $0.range.location < $1.range.location }
    }

    /// One sentence per hit, for a repair prompt or a gate.
    public static func problems(in text: String, path: String?, allowedImports: Swift.Set<String>? = nil) -> [String] {
        hits(in: text, path: path, allowedImports: allowedImports).map { "\($0.location) uses \($0.what): an agent makes no network calls and runs no processes." }
    }

    static let importLine = try! NSRegularExpression(
        pattern: #"^\s*(?:@\w+(?:\([^)]*\))?\s+)*import\s+(?:(?:struct|class|enum|protocol|func|var|let|typealias)\s+)?([A-Za-z_][A-Za-z0-9_]*)"#,
        options: [.anchorsMatchLines])

    static let forbidden: [(NSRegularExpression, String)] = [
        (#"\bURLSession\b|\bURLRequest\b|\bNWConnection\b|\bNWListener\b|\bCFStream\w*|\bimport\s+Network\b|\bWKWebView\b"#, "the network"),
        (#"\bString\s*\(\s*contentsOf:\s*URL\s*\(\s*string:|\bData\s*\(\s*contentsOf:\s*URL\s*\(\s*string:"#, "the network"),
        (#"\bProcess\s*\(|\bNSTask\b|\bposix_spawn\w*|\bfork\s*\(|\bexecv\w*\s*\(|\bsystem\s*\(|\bpopen\s*\("#, "a process"),
        (#"\bdlopen\s*\(|\bdlsym\s*\(|\bNSClassFromString\b|\bBundle\s*\(\s*path:"#, "code loaded at run time"),
    ].map { (try! NSRegularExpression(pattern: $0.0), $0.1) }

    /// Swift without its comments and string literals' contents, so a word in a comment or a message is not a call.
    static func stripped(_ text: String) -> String {
        let code = SwiftManifestReader.stripSwiftComments(text, keepLines: true)
        return code.replacingOccurrences(of: #""(?:[^"\\\n]|\\.)*""#, with: "\"\"", options: .regularExpression)
    }
}
