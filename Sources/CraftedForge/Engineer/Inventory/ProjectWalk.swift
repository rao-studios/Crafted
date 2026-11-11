//  WHAT: The files of a dropped project: git's list in a repository (tracked, plus untracked and not ignored), a walk
//        outside one. Adapted from Craft's ProjectFiles (CraftThread/CodeIndex/Project/ProjectFiles).
//  PIN:  HIDDEN FILES ARE LISTED. Craft's walk skips them; this one lists them so a `.env` gets its verdict (withheld)
//        instead of vanishing. Only `.git` itself is never entered.

import Foundation

public enum ProjectWalk {
    /// Folders no one edits by hand; their files are listed as skipped, their contents never walked.
    static let skippedFolders: [String: FileVerdict] = [
        ".git": .hidden, "node_modules": .vendored, "vendor": .vendored, "Pods": .vendored, "Carthage": .vendored,
        ".build": .generated, "build": .generated, "dist": .generated, "out": .generated, "target": .generated,
        "__pycache__": .generated, ".venv": .vendored, "venv": .vendored, "env": .vendored, ".tox": .generated,
        ".mypy_cache": .generated, ".pytest_cache": .generated, "DerivedData": .generated, ".swiftpm": .generated,
        "coverage": .generated, ".next": .generated, ".gradle": .generated, ".idea": .hidden, ".vscode": .hidden,
    ]

    /// Relative paths of every file under `root`, sorted, and the folders it did not enter with their verdicts.
    public static func list(_ root: URL) -> (files: [String], skipped: [String: FileVerdict]) {
        if let tracked = gitFiles(root) {
            var skipped: [String: FileVerdict] = [:]
            var files: [String] = []
            for path in tracked {
                if let (folder, verdict) = skippedFolder(path) { skipped[folder] = verdict } else { files.append(path) }
            }
            return (files.sorted(), skipped)
        }
        return walk(root)
    }

    static func skippedFolder(_ path: String) -> (String, FileVerdict)? {
        let parts = path.split(separator: "/").map(String.init)
        for (index, part) in parts.dropLast().enumerated() {
            if let verdict = skippedFolders[part] { return (parts[...index].joined(separator: "/"), verdict) }
        }
        return nil
    }

    static func walk(_ root: URL) -> (files: [String], skipped: [String: FileVerdict]) {
        let base = root.standardizedFileURL.resolvingSymlinksInPath().path
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return ([], [:])
        }
        var files: [String] = []
        var skipped: [String: FileVerdict] = [:]
        for case let url as URL in walker {
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard path.hasPrefix(base + "/") else { continue }
            let relative = String(path.dropFirst(base.count + 1))
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }
            if values?.isDirectory == true {
                if let verdict = skippedFolders[url.lastPathComponent] {
                    skipped[relative] = verdict
                    walker.skipDescendants()
                }
                continue
            }
            files.append(relative)
        }
        return (files.sorted(), skipped)
    }

    /// Tracked plus untracked-but-not-ignored, minus deleted; nil when `root` is not a git repository's top.
    static func gitFiles(_ root: URL) -> [String]? {
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent(".git").path) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path, "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return data.split(separator: 0).compactMap { String(data: $0, encoding: .utf8) }
            .filter { !$0.isEmpty && FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }
}
