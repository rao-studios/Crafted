//  WHAT: A package as a pure function of its inputs: a template, an identity, the files code generated (stamped),
//        the files a model or the source supplied (placed as they are), and what to leave out. Instantiate, rename,
//        a changed listing, a dropped command, resume and download again are all one call to `assemble`.
//  IN:   A template folder and its template.json; an AssemblyPlan from a pipeline.
//  OUT:  A fresh tree at the destination, written beside it and swapped in whole.
//  PIN:  NO REGEX OVER MODEL-WRITTEN CODE. Stamping touches the template's own text and the generated files; a
//        `verbatim` overlay (a slot body, a style.json, a font) is placed byte for byte, only its path is stamped.
//  PIN:  PATHS IN PLANS ARE THE TEMPLATE'S. A pipeline names files as the template names them
//        (Sources/SkeletonCore/Logic/TaxRules.swift); the assembler maps the path to the new identity.

import CraftedCore
import Foundation

public struct AssemblyPlan: Sendable {
    public var template: URL
    public var identity: AgentIdentity
    /// Template-named path → text written by code; stamped like the template's own files.
    public var generated: [String: String]
    /// Template-named path → bytes placed as they are (model bodies, data, fonts, pictures).
    public var verbatim: [String: Data]
    /// Template-named paths (files or folders) left out of the package.
    public var remove: [String]

    public init(template: URL, identity: AgentIdentity, generated: [String: String] = [:], verbatim: [String: Data] = [:], remove: [String] = []) {
        self.template = template; self.identity = identity; self.generated = generated; self.verbatim = verbatim; self.remove = remove
    }
}

public struct AssembledTree: Sendable, Equatable {
    public var root: URL
    /// Relative paths, as assembled (stamped).
    public var files: [String]

    public init(root: URL, files: [String]) { self.root = root; self.files = files }
}

public enum PackageAssembler {
    /// Assembles `plan` into `destination` (the package folder itself, named for the package by the caller).
    public static func assemble(_ plan: AssemblyPlan, into destination: URL) throws -> AssembledTree {
        let fm = FileManager.default
        let manifest = try TemplateManifest.read(plan.template)
        let stamp = Stamp(manifest.tokens, plan.identity)
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).assembling-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        var files: Swift.Set<String> = []

        func removed(_ relative: String) -> Bool {
            plan.remove.contains { relative == $0 || relative.hasPrefix($0 + "/") }
        }

        // The template, stamped.
        let base = plan.template.standardizedFileURL.resolvingSymlinksInPath().path
        if let walker = fm.enumerator(at: plan.template, includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let url as URL in walker {
                let path = url.standardizedFileURL.resolvingSymlinksInPath().path
                let relative = String(path.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !relative.isEmpty else { continue }
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if manifest.isSkipped(relative) || removed(relative) {
                    if isDirectory { walker.skipDescendants() }
                    continue
                }
                guard !isDirectory else { continue }
                if plan.generated[relative] != nil || plan.verbatim[relative] != nil { continue }
                let data = try Data(contentsOf: url)
                let output: Data
                if !manifest.isVerbatim(relative), let text = String(data: data, encoding: .utf8) {
                    output = Data(stamp.text(text).utf8)
                } else {
                    output = data
                }
                let target = stamp.path(relative)
                try write(output, staging.appendingPathComponent(target))
                files.insert(target)
            }
        }

        // What code generated: stamped.
        for (relative, text) in plan.generated where !removed(relative) {
            let target = stamp.path(relative)
            try write(Data(stamp.text(text).utf8), staging.appendingPathComponent(target))
            files.insert(target)
        }

        // What a model or the source supplied: as it is.
        for (relative, data) in plan.verbatim where !removed(relative) {
            let target = stamp.path(relative)
            try write(data, staging.appendingPathComponent(target))
            files.insert(target)
        }

        // Swap in whole.
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: staging, to: destination)
        return AssembledTree(root: destination, files: files.sorted())
    }

    /// A template-named path as it will be assembled for `identity`.
    public static func stampedPath(_ relative: String, template: URL, identity: AgentIdentity) throws -> String {
        let manifest = try TemplateManifest.read(template)
        return Stamp(manifest.tokens, identity).path(relative)
    }

    static func write(_ data: Data, _ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}

/// The replacements, longest first: word, display, base, lower base.
struct Stamp {
    let pairs: [(String, String)]
    /// Only the base and lower base rename paths: a word or a display name is never part of one.
    let pathPairs: [(String, String)]

    init(_ tokens: TemplateManifest.Tokens, _ identity: AgentIdentity) {
        pairs = [
            (tokens.word, identity.word),
            (tokens.display, identity.display),
            (tokens.base, identity.base),
            (tokens.lowerBase, identity.lowerBase),
        ].filter { !$0.0.isEmpty }
        pathPairs = [(tokens.base, identity.base), (tokens.lowerBase, identity.lowerBase)].filter { !$0.0.isEmpty }
    }

    func text(_ text: String) -> String {
        pairs.reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }

    func path(_ relative: String) -> String {
        relative.split(separator: "/", omittingEmptySubsequences: false).map { component -> String in
            pathPairs.reduce(String(component)) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
        }.joined(separator: "/")
    }
}
