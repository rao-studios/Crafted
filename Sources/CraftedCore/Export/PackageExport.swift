//  WHAT: The downloadable archive: a filtered copy of the assembled package, zipped as Finder's Archive zips.
//  IN:   A generation's package/<Package>/ folder.
//  OUT:  The listing page's Download; the end-to-end checks (unzip, then swift build).
//  PIN:  STAGE, THEN DITTO. The tree is copied through `ExportFilter` into a temporary folder named for the package,
//        then `ditto -c -k --keepParent` writes `<destination>.partial`, renamed into place: a failed export never
//        leaves a half archive where the person asked for one.
//  PIN:  ONE DESTINATION TODAY. `ExportDestination` is an enum so a later "push to GitHub" is a case, not a rewrite.

import Foundation

public enum ExportDestination: Sendable, Equatable {
    case zip(URL)
}

public enum ExportFilter {
    static let droppedFolders: Swift.Set<String> = [".build", ".swiftpm", ".git", "DerivedData", "xcuserdata", ".crafted"]
    static let droppedNames: Swift.Set<String> = [".DS_Store"]
    static let keptHidden: Swift.Set<String> = [".gitignore", ".gitattributes", ".github", ".spi.yml"]

    /// Whether a path, relative to the package root, ships.
    public static func includes(_ relativePath: String) -> Bool {
        let parts = relativePath.split(separator: "/").map(String.init)
        for part in parts {
            if droppedFolders.contains(part) || droppedNames.contains(part) { return false }
            if part.hasPrefix("._") || part.hasSuffix(".xcuserstate") { return false }
            if part.hasPrefix("."), !keptHidden.contains(part) { return false }
        }
        return true
    }
}

public enum PackageExport {
    public enum Failure: Error, LocalizedError {
        case missing(String)
        case ditto(String)
        public var errorDescription: String? {
            switch self {
            case .missing(let path): return "There is no package at \(path) to download yet."
            case .ditto(let output): return "The archive could not be written: \(output)"
            }
        }
    }

    /// Zips `package` (a folder) to `destination` (a .zip), the folder inside named `name`. Answers the files shipped.
    @discardableResult
    public static func zip(package: URL, named name: String, to destination: URL) throws -> [String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: package.path) else { throw Failure.missing(package.path) }
        let staging = fm.temporaryDirectory.appendingPathComponent("crafted-export-\(UUID().uuidString)", isDirectory: true)
        let staged = staging.appendingPathComponent(name, isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        let shipped = try copyFiltered(from: package, to: staged)

        let partial = destination.deletingLastPathComponent()
            .appendingPathComponent(destination.lastPathComponent + ".partial")
        try? fm.removeItem(at: partial)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", "--norsrc", "--noextattr", "--noqtn", staged.path, partial.path]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            try? fm.removeItem(at: partial)
            throw Failure.ditto(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        try? fm.removeItem(at: destination)
        try fm.moveItem(at: partial, to: destination)
        return shipped
    }

    /// Copies a tree through the filter. Answers the relative paths of the files copied.
    @discardableResult
    public static func copyFiltered(from source: URL, to destination: URL) throws -> [String] {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        var shipped: [String] = []
        let base = source.standardizedFileURL.resolvingSymlinksInPath().path
        guard let walker = fm.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
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
            let target = destination.appendingPathComponent(relative)
            if isDirectory {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: url, to: target)
                shipped.append(relative)
            }
        }
        return shipped.sorted()
    }
}
