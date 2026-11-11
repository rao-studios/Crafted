//  WHAT: What the store reads off a package without building it: the manifest's name, libraries, platforms and
//        Granite dependency; Package.resolved's Granite pin; the recorded types and the word, reading at most 20
//        Swift files in the store's order; and the licence its LICENSE file says plainly.
//  IN:   craft.rao.nyc app/(store)/_lib/formats/swift-package/index.ts `inspect`, ported step for step: the read
//        loop, its budget, and its fallback (a record found but its type's file not reached: the one word among the
//        files read is the word).
//  OUT:  StoreValidator (the rules), crafted-check validate.

import CraftedCore
import Foundation

public struct StoreInspection: Sendable, Equatable {
    public var hasManifest: Bool
    public var manifest: SwiftManifest
    public var graniteRevision: String?
    public var hasResolved: Bool
    public var recordTypes: [String]
    public var word: String?
    /// Whether the word was read in the file declaring a recorded type (not the store's one-word fallback).
    public var wordBesideType: Bool
    /// The Swift files read, in the order read.
    public var read: [String]
    public var licence: ListingLicence?
    public var licenceFile: String?
    /// The store's own sentences: what makes it not an agent.
    public var problems: [String]

    /// How many Swift files are read looking for the record and the word.
    public static let sourceFilesMax = 20

    public static func inspect(package: URL) -> StoreInspection {
        let manifestText = try? String(contentsOf: package.appendingPathComponent("Package.swift"), encoding: .utf8)
        guard let manifestText else {
            return StoreInspection(hasManifest: false, manifest: SwiftManifest(name: nil, libraries: [], platforms: [], dependsOnGranite: false),
                                   graniteRevision: nil, hasResolved: false, recordTypes: [], word: nil, wordBesideType: false,
                                   read: [], licence: nil, licenceFile: nil, problems: ["No Package.swift at the root."])
        }
        var problems: [String] = []
        let manifest = SwiftManifestReader.parse(manifestText)
        if manifest.name == nil { problems.append("Its Package.swift doesn’t name the package plainly (`name: \"…\"`).") }
        if !manifest.dependsOnGranite { problems.append("Its Package.swift doesn’t depend on Granite.") }
        if manifest.libraries.isEmpty { problems.append("It makes no library product.") }

        let resolvedText = try? String(contentsOf: package.appendingPathComponent("Package.resolved"), encoding: .utf8)
        let granite = resolvedText.flatMap(ResolvedReader.graniteRevision)

        let entries = ShipGate.shippedFiles(in: package).map { path in
            SwiftSourceReader.Entry(path: path, size: (try? package.appendingPathComponent(path)
                .resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        var types: [String] = []
        var word: String?
        var words: [String] = []
        var read: [String] = []
        var budget = sourceFilesMax
        while budget > 0, word == nil {
            guard let next = SwiftSourceReader.order(entries, packageName: manifest.name, types: types)
                .first(where: { !read.contains($0.path) }) else { break }
            read.append(next.path)
            budget -= 1
            guard let text = try? String(contentsOf: package.appendingPathComponent(next.path), encoding: .utf8), !text.isEmpty else { continue }
            for type in SwiftSourceReader.recordTypes(text) where !types.contains(type) { types.append(type) }
            if let found = SwiftSourceReader.word(in: text) {
                if !words.contains(found) { words.append(found) }
                if types.contains(where: { SwiftSourceReader.declaresType(text, $0) }) { word = found }
            }
        }
        let besideType = word != nil
        if word == nil, !types.isEmpty, words.count == 1 { word = words[0] }
        if types.isEmpty {
            problems.append("No GraniteAgentPackage record was found in its sources (`GraniteRoster.record(YourAgent.self)`).")
        }

        let licenceFile = LicenceRecogniser.licenceFile(in: package)
        return StoreInspection(hasManifest: true, manifest: manifest, graniteRevision: granite, hasResolved: resolvedText != nil,
                               recordTypes: types, word: word, wordBesideType: besideType, read: read,
                               licence: licenceFile.flatMap { LicenceRecogniser.licence(in: $0.text) },
                               licenceFile: licenceFile?.path, problems: problems)
    }
}
