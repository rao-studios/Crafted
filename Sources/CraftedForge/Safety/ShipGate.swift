//  WHAT: The last check before a package leaves: every file that would ship (ExportFilter's view of the tree) is
//        scanned for secret-shaped names, secrets in its text, private details, and licence notices the package
//        cannot carry. Any finding fails the gate, one sentence each with its fix.
//  IN:   The assembled package folder.
//  OUT:  Forge.assemble (the "ship" gate), so `export` refuses to zip a package that fails it.
//  PIN:  WHAT SHIPS IS WHAT IS SCANNED. The walk uses ExportFilter, the same filter the zip uses, so a secret in
//        .build/ does not fail the gate and a secret in a kept .github/ does.

import CraftedCore
import Foundation

public enum ShipGate {
    public static let name = "ship"
    /// Files larger than this are not read for text (they are pictures, fonts, archives).
    static let textLimit = 8 * 1024 * 1024
    /// Detail lines shown before "… and N more".
    static let shown = 12

    public static func check(package: URL) -> GateResult {
        let (problems, scanned) = scan(package: package)
        if problems.isEmpty {
            return GateResult(name: name, passed: true,
                              detail: ["Scanned \(scanned) files: no secrets, private paths or licence notices it cannot carry."])
        }
        var detail = Array(problems.prefix(shown))
        if problems.count > shown { detail.append("… and \(problems.count - shown) more.") }
        return GateResult(name: name, passed: false, detail: detail)
    }

    /// Every problem, one sentence each, and how many files were scanned.
    public static func scan(package: URL) -> (problems: [String], scanned: Int) {
        let licence = LicenceRecogniser.licence(ofPackage: package)
        var problems: [String] = []
        var scanned = 0
        for relative in shippedFiles(in: package) {
            scanned += 1
            if let reason = SecretNames.reason(relative) {
                problems.append("\(relative) is \(reason) and would ship: take it out of the package.")
                continue
            }
            guard let text = readText(package.appendingPathComponent(relative)) else { continue }
            for hit in SecretScan.hits(in: text, path: relative) {
                problems.append("\(hit.sentence.dropLast()): remove it; an agent takes what it needs from its input.")
            }
            for hit in PrivacyScan.hits(in: text, path: relative) {
                let fix = hit.what == PrivacyScan.homeWhat ? "use a path relative to the package" : "remove it or replace it with an example"
                problems.append("\(hit.sentence.dropLast()): \(fix).")
            }
            for hit in LicenceScan.hits(in: text, path: relative, packageLicence: licence) {
                problems.append("\(hit.sentence.dropLast()), which a \(licence?.rawValue ?? "package without a recognised") licence cannot carry: rewrite the file or choose GPL-3.0.")
            }
        }
        return (problems, scanned)
    }

    /// The relative paths of every file that would ship.
    public static func shippedFiles(in package: URL) -> [String] {
        let fm = FileManager.default
        let base = package.standardizedFileURL.resolvingSymlinksInPath().path
        guard let walker = fm.enumerator(at: package, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        var files: [String] = []
        for case let url as URL in walker {
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard path.hasPrefix(base) else { continue }
            let relative = String(path.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !relative.isEmpty else { continue }
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard ExportFilter.includes(relative) else {
                if isDirectory { walker.skipDescendants() }
                continue
            }
            if !isDirectory { files.append(relative) }
        }
        return files.sorted()
    }

    /// A file's text, or nil when it is binary or too large to be text.
    static func readText(_ url: URL) -> String? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= textLimit, let data = try? Data(contentsOf: url) else { return nil }
        if data.prefix(8192).contains(0) { return nil }
        return String(data: data, encoding: .utf8)
    }
}
