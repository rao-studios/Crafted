//  WHAT: The inventory of a dropped project: every file listed, a verdict for each, every opened file's text scanned
//        for secrets and redacted, its hash and lines counted, and the source's licence read off its LICENSE.
//  IN:   The dropped folder.
//  OUT:  Inventory (the run's inventory.json), and a finding for each file withheld and each secret redacted.
//  PIN:  NAMES FIRST, CONTENT SECOND. A secret-shaped name is withheld before anything opens it (SecretNames); every
//        other opened file is redacted (SecretScan) before it is kept, so no later stage can see a secret.

import CraftedCore
import Foundation

public enum InventoryReader {
    static let maxBytes = 512 * 1024

    static let manifests: Swift.Set<String> = [
        "package.json", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "pipfile", "package.swift",
        "cargo.toml", "go.mod", "gemfile", "pom.xml", "build.gradle", "build.gradle.kts", "composer.json", "makefile",
    ]
    static let lockfiles: Swift.Set<String> = [
        "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "pipfile.lock", "poetry.lock", "package.resolved",
        "cargo.lock", "gemfile.lock", "composer.lock", "go.sum", "uv.lock",
    ]
    static let dataExtensions: Swift.Set<String> = ["json", "csv", "tsv", "yaml", "yml", "toml", "txt", "xml", "plist", "ini", "tmpl", "html", "css"]
    static let docExtensions: Swift.Set<String> = ["md", "rst", "adoc"]
    static let mediaExtensions: Swift.Set<String> = [
        "png", "jpg", "jpeg", "gif", "svg", "webp", "heic", "ico", "icns", "pdf", "mp3", "mp4", "mov", "wav", "aiff",
        "ttf", "otf", "woff", "woff2", "zip", "gz", "tar", "dylib", "a", "o", "so", "bin", "safetensors", "metallib", "pyc",
    ]

    public struct Read: Sendable {
        public var inventory: Inventory
        public var findings: [Finding]
    }

    public static func read(_ root: URL) -> Read {
        let (paths, skippedFolders) = ProjectWalk.list(root)
        var files: [InventoryFile] = []
        var texts: [String: String] = [:]
        var findings: [Finding] = []
        for (folder, verdict) in skippedFolders.sorted(by: { $0.key < $1.key }) {
            files.append(InventoryFile(path: folder + "/", verdict: verdict))
        }
        for path in paths {
            if SecretNames.isWithheld(path) {
                files.append(InventoryFile(path: path, verdict: .withheld))
                findings.append(Finding(.withheld, "\(path) was not read: its name says it holds secrets (\(SecretNames.reason(path) ?? "a secret")).", path: path))
                continue
            }
            let verdict = classify(path)
            guard verdict.isOpened else {
                let size = (try? FileManager.default.attributesOfItem(atPath: root.appendingPathComponent(path).path)[.size] as? Int) ?? 0
                files.append(InventoryFile(path: path, verdict: verdict, bytes: size))
                continue
            }
            let url = root.appendingPathComponent(path)
            guard let data = try? Data(contentsOf: url) else {
                files.append(InventoryFile(path: path, verdict: .unknown))
                continue
            }
            if data.count > maxBytes {
                files.append(InventoryFile(path: path, verdict: .large, bytes: data.count))
                findings.append(Finding(.skipped, "\(path) is over 512 KB, so it was listed and not read.", path: path))
                continue
            }
            if data.prefix(8192).contains(0) {
                files.append(InventoryFile(path: path, verdict: .binary, bytes: data.count))
                continue
            }
            let raw = String(decoding: data, as: UTF8.self)
            let hits = SecretScan.hits(in: raw, path: path)
            findings += SecretScan.findings(in: raw, path: path)
            let text = hits.isEmpty ? raw : SecretScan.redact(raw)
            texts[path] = text
            files.append(InventoryFile(path: path, verdict: verdict, language: SourceLanguage.of(path), bytes: data.count,
                                       lines: SourceText.lines(text).count, sha256: ContentHash.sha256(text), redacted: hits.map(\.line)))
        }
        let licenceFile = files.first { ["license", "license.md", "license.txt", "licence", "licence.md", "copying"].contains($0.path.lowercased()) }
        let licence = licenceFile.flatMap { texts[$0.path] }.flatMap { LicenceRecogniser.licence(in: $0)?.rawValue }
        return Read(inventory: Inventory(files: files.sorted { $0.path < $1.path }, texts: texts, licence: licence), findings: findings)
    }

    /// A file's verdict from its path alone.
    static func classify(_ path: String) -> FileVerdict {
        let name = (path as NSString).lastPathComponent
        let lower = name.lowercased()
        let ext = (name as NSString).pathExtension.lowercased()
        let parts = path.lowercased().split(separator: "/").map(String.init)
        if lockfiles.contains(lower) { return .lockfile }
        if name.hasPrefix(".") || parts.dropLast().contains(where: { $0.hasPrefix(".") }) { return .hidden }
        if mediaExtensions.contains(ext) { return .media }
        if manifests.contains(lower) { return .manifest }
        if lower.hasPrefix("readme") || lower.hasPrefix("license") || lower.hasPrefix("licence") || lower.hasPrefix("changelog")
            || lower == "copying" || docExtensions.contains(ext) {
            return .doc
        }
        if SourceLanguage.of(path) != nil { return isTest(path) ? .test : .read }
        if dataExtensions.contains(ext) { return isTest(path) ? .test : .resource }
        return .unknown
    }

    static func isTest(_ path: String) -> Bool {
        let lower = path.lowercased()
        let parts = lower.split(separator: "/").map(String.init)
        if parts.dropLast().contains(where: { ["test", "tests", "__tests__", "spec", "specs", "testing"].contains($0) || $0.hasSuffix("tests") }) {
            return true
        }
        let name = parts.last ?? ""
        return name.hasPrefix("test_") || name.contains("_test.") || name.contains(".test.") || name.contains(".spec.")
            || name.hasSuffix("tests.swift") || name.hasSuffix("test.swift")
    }
}
