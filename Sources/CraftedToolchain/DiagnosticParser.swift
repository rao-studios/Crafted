//  WHAT: The compiler's diagnostics out of a build's output: `file:line:col: error|warning|note: message`, in the
//        order said, each once, with paths made relative to the package.
//  IN:   `swift build … -Xswiftc -diagnostic-style=llvm` output (stdout and stderr together).
//  OUT:  BuildResult.diagnostics, TestResult.diagnostics (tests that did not build), the port loop's repair prompts.
//  PIN:  ONCE EACH. SwiftPM repeats a file's errors (the compile and the emit-module job say them both); a
//        diagnostic seen again is dropped.
//  PIN:  A FAILURE IS NEVER SILENT. When the build failed and no located error was said (a manifest error, a
//        dependency that would not resolve, a link error), SwiftPM's own `error:` lines become diagnostics with no file.

import CraftedForge
import Foundation

enum DiagnosticParser {
    static let located = try! NSRegularExpression(
        pattern: #"^(.+?):(\d+):(\d+): (error|warning|note): (.*)$"#, options: [.anchorsMatchLines])
    static let general = try! NSRegularExpression(
        pattern: #"^(?:<unknown>:0: |ld: |clang: )?(error): (.*)$"#, options: [.anchorsMatchLines])

    /// Every located diagnostic in `output`, once each; when `failed` and none is an error, the general errors too.
    static func parse(_ raw: String, package: URL?, failed: Bool) -> [Diagnostic] {
        let output = stripANSI(raw)
        let prefixes = package.map(Self.prefixes) ?? []
        var seen: Swift.Set<Diagnostic> = []
        var found: [Diagnostic] = []
        let ns = output as NSString
        for match in located.matches(in: output, range: NSRange(location: 0, length: ns.length)) {
            let file = relative(ns.substring(with: match.range(at: 1)), prefixes)
            guard let line = Int(ns.substring(with: match.range(at: 2))),
                  let column = Int(ns.substring(with: match.range(at: 3))),
                  let severity = Diagnostic.Severity(rawValue: ns.substring(with: match.range(at: 4))) else { continue }
            let diagnostic = Diagnostic(file: file, line: line, column: column, severity: severity,
                                        message: ns.substring(with: match.range(at: 5)).trimmingCharacters(in: .whitespaces))
            if seen.insert(diagnostic).inserted { found.append(diagnostic) }
        }
        if failed, !found.contains(where: { $0.severity == .error }) {
            for match in general.matches(in: output, range: NSRange(location: 0, length: ns.length)) {
                let message = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
                guard !isNoise(message) else { continue }
                let diagnostic = Diagnostic(file: "", line: 0, column: 0, severity: .error, message: message)
                if seen.insert(diagnostic).inserted { found.append(diagnostic) }
            }
        }
        return found
    }

    /// Output without terminal colour codes (a build system that colours even off a terminal).
    static func stripANSI(_ text: String) -> String {
        guard text.contains("\u{1B}") else { return text }
        return text.replacingOccurrences(of: #"\u001B\[[0-9;]*[A-Za-z]"#, with: "", options: .regularExpression)
    }

    /// SwiftPM's summary lines that only say a job failed, not why.
    static func isNoise(_ message: String) -> Bool {
        message.contains("command failed with exit code") || message.hasPrefix("fatalError")
    }

    /// The package's path as the compiler may print it: as given, and with /var resolved to /private/var.
    static func prefixes(_ package: URL) -> [String] {
        let given = package.standardizedFileURL.path
        let resolved = package.resolvingSymlinksInPath().path
        return Array(Swift.Set([given, resolved, "/private" + given])).map { $0.hasSuffix("/") ? $0 : $0 + "/" }
    }

    static func relative(_ path: String, _ prefixes: [String]) -> String {
        for prefix in prefixes where path.hasPrefix(prefix) { return String(path.dropFirst(prefix.count)) }
        return path
    }
}
