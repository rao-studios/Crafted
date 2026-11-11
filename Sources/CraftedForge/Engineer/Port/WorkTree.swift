//  WHAT: The two trees a port builds in: the last good package (work/package), which always builds, and a scratch copy
//        (work/scratch) that is the last good tree plus the one file being tried. A pass promotes the file into both;
//        a fail puts the scratch file back.
//  IN:   The run, the template, the identity the port is named with.
//  OUT:  PortLoop (candidates and promotions), the gates (the last good tree).
//  PIN:  THE LAST GOOD TREE ALWAYS BUILDS. Nothing is written into it that has not built and passed in the scratch.

import CraftedCore
import Foundation

struct WorkTree: Sendable {
    let run: RunFolder
    let template: URL
    let identity: AgentIdentity

    var package: URL { run.workPackage }
    var scratch: URL { run.workScratch }

    /// Assembles the last good tree from the artefacts and copies it to the scratch.
    func rebuild(_ artefacts: PortArtefacts) throws {
        try EngineerAssembly.assemble(template: template, identity: identity, artefacts: artefacts, into: package)
        try resetScratch()
    }

    func resetScratch() throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: scratch.path) { try manager.removeItem(at: scratch) }
        try manager.createDirectory(at: scratch.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.copyItem(at: package, to: scratch)
    }

    /// A template path as this tree names it.
    func path(_ templatePath: String) throws -> String {
        try PackageAssembler.stampedPath(templatePath, template: template, identity: identity)
    }

    /// A target or test filter as this tree names it.
    func stamped(_ name: String) -> String {
        name.replacingOccurrences(of: "Skeleton", with: identity.base)
    }

    /// Runs `body` with `text` at `templatePath` in the scratch, then puts the scratch file back.
    func trying<T>(_ templatePath: String, _ text: String, _ body: () async throws -> T) async throws -> T {
        let relative = try path(templatePath)
        let candidate = scratch.appendingPathComponent(relative)
        let good = package.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: candidate.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: candidate)
        defer {
            if let data = try? Data(contentsOf: good) { try? data.write(to: candidate) } else { try? FileManager.default.removeItem(at: candidate) }
        }
        return try await body()
    }

    /// Writes `text` at `templatePath` in both trees.
    func promote(_ templatePath: String, _ text: String) throws {
        let relative = try path(templatePath)
        for root in [package, scratch] {
            let url = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
        }
    }
}
