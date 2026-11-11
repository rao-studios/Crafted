//  WHAT: The store's static check of a package, ported rule for rule from craft.rao.nyc's validator, so what the
//        store would refuse is caught before the person pushes: Package.swift names the package, depends on Granite
//        and makes a library named as the package; a record is found (record files first, 20 Swift files at most)
//        and the word beside the recorded type matches the listing's; Assets/listing.json keeps the store's limits;
//        the icon is a square PNG of 512 px or more and 6 MB at most; LICENSE is one the store recognises; there is a
//        README; Package.resolved pins Granite to a full commit.
//  IN:   craft.rao.nyc app/(store)/_lib/formats/swift-package/{index,manifest,sources,resolved}.ts,
//        source/{listing-json,snapshot}.ts, listing-rules.ts, README "GitHub" (2026-11-10). The readers beside this
//        file are the ports; this file is the rules and their sentences.
//  OUT:  Forge.assemble (the "store" gate), crafted-check validate.
//  PIN:  ONE SENTENCE, ONE FIX. Each failure says what the store will refuse and what to change.
//  PIN:  STRICTER ONLY WHERE CRAFTED KNOWS MORE. The store sets a bad listing.json key aside and lists the rest;
//        here every key set aside is a failure, and the names must be the identity's, because Crafted wrote them.

import CraftedCore
import Foundation

public enum StoreValidator {
    public static let name = "store"
    public static let readme = #"(?i)^readme(?:\.md|\.markdown)?$"#

    public static func check(package: URL, identity: AgentIdentity) -> GateResult {
        let found = inspect(package: package)
        let problems = problems(found, package: package, identity: identity)
        if problems.isEmpty {
            let pin = found.graniteRevision.map { String($0.prefix(7)) } ?? "?"
            return GateResult(name: name, passed: true, detail: [
                "Read as the store reads it: \(identity.package), $\(found.word ?? identity.word), Granite \(pin), "
                    + "\(found.licence?.rawValue ?? "?") licence, listing.json, icon and README.",
            ])
        }
        return GateResult(name: name, passed: false, detail: problems)
    }

    /// What the store reads off the package.
    public static func inspect(package: URL) -> StoreInspection { StoreInspection.inspect(package: package) }

    /// Every rule the package breaks, one sentence each with its fix.
    public static func problems(_ found: StoreInspection, package: URL, identity: AgentIdentity) -> [String] {
        guard found.hasManifest else {
            return ["There is no Package.swift at the package's root: a Craft agent is a Swift package; assemble it again."]
        }
        var problems: [String] = []
        problems += manifestProblems(found.manifest, identity: identity)
        problems += recordProblems(found, identity: identity)
        problems += listingProblems(package: package, identity: identity, licence: found.licence)
        problems += IconCheck.problems(inPackage: package)
        problems += documentProblems(found, package: package)
        return problems
    }

    // MARK: The rules

    static func manifestProblems(_ manifest: SwiftManifest, identity: AgentIdentity) -> [String] {
        var problems: [String] = []
        if let name = manifest.name {
            if name != identity.package {
                problems.append("Package.swift names the package \(name), not \(identity.package): assemble it again with the listing's name.")
            }
        } else {
            problems.append("Package.swift does not name the package plainly: write `name: \"\(identity.package)\"` in Package(…), not a variable.")
        }
        if !manifest.dependsOnGranite {
            problems.append("Package.swift does not depend on Granite: add `.package(url: \"https://github.com/riteshpakala/Granite.git\", branch: \"main\")`.")
        }
        if manifest.libraries.isEmpty {
            problems.append("Package.swift makes no library product: add `.library(name: \"\(identity.package)\", targets: [\"\(identity.agentTarget)\"])`.")
        } else if !manifest.libraries.contains(identity.package) {
            problems.append("Package.swift makes no library named \(identity.package) (it makes \(manifest.libraries.joined(separator: ", "))): name the library as the package.")
        }
        return problems
    }

    static func recordProblems(_ found: StoreInspection, identity: AgentIdentity) -> [String] {
        guard !found.recordTypes.isEmpty else {
            return ["No GraniteAgentPackage record was found in the first \(StoreInspection.sourceFilesMax) Swift files the store reads: "
                    + "put `GraniteRoster.record(\(identity.typeName).self)` in Sources/\(identity.agentTarget)/\(identity.base)Record.swift."]
        }
        let type = found.recordTypes[0]
        guard let word = found.word else {
            return ["The word is not a literal the store can read: write `public static let word = \"\(identity.word)\"` in the file that declares \(type)."]
        }
        var problems: [String] = []
        if let problem = AgentNameRules.wordProblem(word) {
            problems.append("The package's word \"\(word)\" cannot be listed (\(problem.dropLast())): choose another in the listing and assemble again.")
        }
        if word != identity.word {
            problems.append("The package's word is \"\(word)\" but the listing's is \"\(identity.word)\": assemble it again so they match.")
        }
        return problems
    }

    static func listingProblems(package: URL, identity: AgentIdentity, licence: ListingLicence?) -> [String] {
        let url = package.appendingPathComponent(ListingJSONReader.path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ["There is no \(ListingJSONReader.path): the store reads the listing's name, tagline and category from it; save the listing and assemble again."]
        }
        let parsed = ListingJSONReader.parse(text)
        var problems = parsed.notes.map { $0.hasSuffix(".") ? $0 : $0 + "." }
        // The form's own rules, where the store's reader did not already speak to the key.
        let listing = AgentListing(name: parsed.name ?? "", word: identity.word, tagline: parsed.tagline ?? "",
                                   keywords: parsed.keywords ?? [], platforms: parsed.platforms ?? [])
        for problem in ListingRules.problems(listing, role: .engineer) where problem.key != .word {
            let key = problem.key.rawValue
            if parsed.flagged.contains(key) { continue }
            problems.append("“\(key)” in \(ListingJSONReader.path): \(problem.message)")
        }
        if let said = parsed.license, let licence, said != licence.rawValue {
            problems.append("\(ListingJSONReader.path) says the licence is \(said) but LICENSE is \(licence.rawValue): choose one in the listing and assemble again.")
        }
        return problems
    }

    static func documentProblems(_ found: StoreInspection, package: URL) -> [String] {
        var problems: [String] = []
        if let file = found.licenceFile {
            if found.licence == nil {
                problems.append("\(file) does not say plainly which licence it is: use the full text of MIT, Apache-2.0, MPL-2.0, GPL-3.0, BSD-2-Clause, BSD-3-Clause or ISC.")
            }
        } else {
            problems.append("There is no LICENSE file: choose a licence in the listing and assemble again.")
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: package.path)) ?? []
        if !names.contains(where: { StoreRegex.test(readme, $0) }) {
            problems.append("There is no README.md: the store shows it as the agent's description; assemble again.")
        }
        if !found.hasResolved {
            problems.append("There is no Package.resolved: run `swift package resolve` so Granite is pinned to a commit.")
        } else if found.graniteRevision == nil {
            problems.append("Package.resolved does not pin Granite to a full commit: run `swift package resolve` and keep the file.")
        }
        return problems
    }
}
