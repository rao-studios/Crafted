//  WHAT: The store validator port: the store's own cases (craft.rao.nyc formats/swift-package/*.test.ts) replayed
//        against the Swift readers, then a good package that passes and a broken one that fails each rule with its
//        sentence.

@testable import CraftedForge
import CraftedCore
import XCTest

final class StoreValidatorTests: XCTestCase {
    // MARK: The store's cases

    func testMarbleManifestAndPlatePlatformsAndComments() {
        XCTAssertEqual(SwiftManifestReader.parse(StoreFixtures.marblePackage),
                       SwiftManifest(name: "MarbleAgent", libraries: ["MarbleAgent"], platforms: ["macOS 14"], dependsOnGranite: true))
        let plate = SwiftManifestReader.parse(StoreFixtures.platePackage)
        XCTAssertEqual(plate.name, "PlateAgent")
        XCTAssertEqual(plate.platforms, ["macOS 26"])
        XCTAssertTrue(plate.dependsOnGranite)
        XCTAssertEqual(SwiftManifestReader.stripSwiftComments("let u = \"https://github.com/a/b\" // gone\n/* a /* b */ c */ kept"),
                       "let u = \"https://github.com/a/b\" \n  kept")
        let many = SwiftManifestReader.parse(#"let package = Package(name: "X", platforms: [.macOS(.v10_15), .iOS("17.2"), .iOS(.v17), .iOS("17.0")])"#)
        XCTAssertEqual(many.platforms, ["macOS 10.15", "iOS 17.2", "iOS 17"])
    }

    func testGraniteIsFoundByIdentity() {
        XCTAssertEqual(SwiftManifestReader.packageIdentity("https://github.com/riteshpakala/Granite.git"), "granite")
        XCTAssertEqual(SwiftManifestReader.packageIdentity("git@github.com:someone/granite"), "granite")
        XCTAssertEqual(SwiftManifestReader.packageIdentity("../Granite/"), "granite")
        XCTAssertEqual(SwiftManifestReader.packageIdentity("https://github.com/x/GraniteKit.git"), "granitekit")
        XCTAssertTrue(SwiftManifestReader.parse(#"let package = Package(name: "X", products: [.library(name: "X", targets: ["X"])], dependencies: [.package(path: "../Granite")])"#).dependsOnGranite)
        XCTAssertFalse(SwiftManifestReader.parse("let package = Package(name: \"X\", dependencies: [ // .package(url: \"https://github.com/a/Granite.git\", branch: \"main\"),\n])").dependsOnGranite)
        XCTAssertEqual(SwiftManifestReader.parse("let name = \"X\"\nlet package = Package(name: name)"),
                       SwiftManifest(name: nil, libraries: [], platforms: [], dependsOnGranite: false))
    }

    func testSourcesRecordWordDeclarationLicence() {
        XCTAssertEqual(SwiftSourceReader.recordTypes(StoreFixtures.marbleRecord), ["MarbleAgent"])
        XCTAssertEqual(SwiftSourceReader.recordTypes("{ GraniteRoster.record(worker: Kit.ShellWorker.self) }"), ["ShellWorker"])
        XCTAssertEqual(SwiftSourceReader.recordTypes("let x = 1"), [])
        XCTAssertEqual(SwiftSourceReader.word(in: StoreFixtures.marbleAgent), "marble")
        XCTAssertEqual(SwiftSourceReader.word(in: #"static var word: String { "plate" }"#), "plate")
        XCTAssertEqual(SwiftSourceReader.word(in: #"static var word: String { return "plate" }"#), "plate")
        XCTAssertNil(SwiftSourceReader.word(in: #"let word = "nope""#))
        XCTAssertTrue(SwiftSourceReader.declaresType(StoreFixtures.marbleAgent, "MarbleAgent"))
        XCTAssertTrue(SwiftSourceReader.declaresType("extension GraniteAppAgent: GraniteAgentPackage {", "GraniteAppAgent"))
        XCTAssertFalse(SwiftSourceReader.declaresType("struct MarbleAgentTests {", "MarbleAgent"))
        XCTAssertEqual(LicenceRecogniser.licence(in: StoreFixtures.mit), .mit)
        XCTAssertEqual(LicenceRecogniser.licence(in: "                                 Apache License\n                           Version 2.0, January 2004"), .apache2)
        XCTAssertNil(LicenceRecogniser.licence(in: "All rights reserved."))
    }

    func testResolvedVersions() {
        XCTAssertEqual(ResolvedReader.graniteRevision(StoreFixtures.plateResolved), "e64723f3e3fde412622f369a8ca7766ba2777119")
        let v1 = #"{"object":{"pins":[{"package":"Granite","repositoryURL":"https://github.com/riteshpakala/Granite.git","state":{"branch":"main","revision":"29ae42af292f8f3ad0e862af01fa537307117793"}}]},"version":1}"#
        XCTAssertEqual(ResolvedReader.graniteRevision(v1), "29ae42af292f8f3ad0e862af01fa537307117793")
        XCTAssertNil(ResolvedReader.graniteRevision(#"{"pins":[{"identity":"swift-syntax","state":{"revision":"29ae42af292f8f3ad0e862af01fa537307117793"}}],"version":2}"#))
        XCTAssertNil(ResolvedReader.graniteRevision(#"{"pins":[{"identity":"granite","state":{"revision":"29ae42a"}}],"version":2}"#))
        XCTAssertNil(ResolvedReader.graniteRevision("nope"))
    }

    func testMarbleIsReadRecordFileFirst() throws {
        var files = [
            "Package.swift": StoreFixtures.marblePackage, "Package.resolved": StoreFixtures.plateResolved, "LICENSE": StoreFixtures.mit,
            "Sources/MarbleAgent/MarbleAgent.swift": StoreFixtures.marbleAgent,
            "Sources/MarbleAgent/MarbleRecord.swift": StoreFixtures.marbleRecord,
        ]
        for index in 0..<30 { files["Sources/MarbleAgent/Filters/F\(index).swift"] = "// a filter" }
        let package = try StoreFixtures.folder(files)
        defer { try? FileManager.default.removeItem(at: package) }
        let found = StoreInspection.inspect(package: package)
        XCTAssertEqual(found.manifest.name, "MarbleAgent")
        XCTAssertEqual(found.graniteRevision, "e64723f3e3fde412622f369a8ca7766ba2777119")
        XCTAssertEqual(found.word, "marble")
        XCTAssertEqual(found.licence, .mit)
        XCTAssertEqual(found.problems, [])
        XCTAssertEqual(found.read, ["Sources/MarbleAgent/MarbleRecord.swift", "Sources/MarbleAgent/MarbleAgent.swift"])
    }

    func testRecordTypeInAnotherFileStillFindsTheWord() throws {
        let package = try StoreFixtures.folder([
            "Package.swift": StoreFixtures.marblePackage.replacingOccurrences(of: "MarbleAgent", with: "GraniteAgent"),
            "Sources/GraniteAgent/GraniteRecord.swift": "let r: GraniteRoster.Record = { GraniteRoster.record(GraniteAppAgent.self) }",
            "Sources/GraniteAgent/App/GraniteAppAgent.swift": "public struct GraniteAppAgent: GraniteAgentPackage {\n  public static let word = \"granite\"\n}",
        ])
        defer { try? FileManager.default.removeItem(at: package) }
        let found = StoreInspection.inspect(package: package)
        XCTAssertEqual(found.word, "granite")
        XCTAssertEqual(found.problems, [])
    }

    func testNotAnAgentSaysEachReason() throws {
        let package = try StoreFixtures.folder([
            "Package.swift": #"let package = Package(name: "Tool", products: [.executable(name: "tool", targets: ["Tool"])])"#,
            "Sources/Tool/main.swift": "print(1)",
        ])
        defer { try? FileManager.default.removeItem(at: package) }
        XCTAssertEqual(StoreInspection.inspect(package: package).problems, [
            "Its Package.swift doesn’t depend on Granite.",
            "It makes no library product.",
            "No GraniteAgentPackage record was found in its sources (`GraniteRoster.record(YourAgent.self)`).",
        ])
    }

    func testListingJSONNotes() {
        XCTAssertEqual(ListingJSONReader.parse("{").notes, ["Assets/listing.json isn’t valid JSON, so none of it was read."])
        let parsed = ListingJSONReader.parse(#"{"name": "", "category": "games", "keywords": ["ok", "Not OK!"], "platforms": [], "description": "x"}"#)
        XCTAssertEqual(parsed.flagged, ["name", "category", "keywords", "platforms", "description"])
        XCTAssertEqual(parsed.keywords, ["ok"])
    }

    // MARK: A whole package

    func testAGoodPackagePasses() throws {
        let identity = AgentIdentity.derive(display: "Invoice Totals")
        let package = try StoreFixtures.goodPackage(identity)
        defer { try? FileManager.default.removeItem(at: package) }
        let gate = StoreValidator.check(package: package, identity: identity)
        XCTAssertTrue(gate.passed, gate.detail.joined(separator: "\n"))
        XCTAssertTrue(ShipGate.check(package: package).passed)
    }

    func testABrokenPackageFailsEachRuleWithItsFix() throws {
        let identity = AgentIdentity.derive(display: "Invoice Totals")
        let package = try StoreFixtures.goodPackage(identity)
        defer { try? FileManager.default.removeItem(at: package) }
        let fm = FileManager.default
        try #"let package = Package(name: "OtherAgent", products: [.library(name: "Other", targets: ["Other"])])"#
            .write(to: package.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try StoreFixtures.agentSource(identity).replacingOccurrences(of: "\"invoicetotals\"", with: "\"invoices\"")
            .write(to: package.appendingPathComponent("Sources/InvoiceTotalsAgent/InvoiceTotalsAgent.swift"), atomically: true, encoding: .utf8)
        try #"{"name": "Invoice Totals", "tagline": "Totals.", "category": "data", "keywords": ["Bad!"], "platforms": ["macOS 26"], "license": "MIT"}"#
            .write(to: package.appendingPathComponent("Assets/listing.json"), atomically: true, encoding: .utf8)
        try StoreFixtures.png(width: 600, height: 300).write(to: package.appendingPathComponent("Assets/icon.png"))
        try "All rights reserved.".write(to: package.appendingPathComponent("LICENSE"), atomically: true, encoding: .utf8)
        try fm.removeItem(at: package.appendingPathComponent("README.md"))
        try #"{"pins":[{"identity":"granite","state":{"revision":"29ae42a"}}],"version":2}"#
            .write(to: package.appendingPathComponent("Package.resolved"), atomically: true, encoding: .utf8)

        let gate = StoreValidator.check(package: package, identity: identity)
        XCTAssertFalse(gate.passed)
        let detail = gate.detail.joined(separator: "\n")
        for expected in ["names the package OtherAgent, not InvoiceTotalsAgent", "does not depend on Granite",
                         "makes no library named InvoiceTotalsAgent", "word is \"invoices\" but the listing's is \"invoicetotals\"",
                         "“keywords” in Assets/listing.json", "600×300", "LICENSE does not say plainly which licence",
                         "There is no README.md", "does not pin Granite to a full commit"] {
            XCTAssertTrue(detail.contains(expected), "missing: \(expected)\n\(detail)")
        }
        XCTAssertTrue(gate.detail.allSatisfy { $0.contains(":") }, "each sentence carries its fix")
    }
}
