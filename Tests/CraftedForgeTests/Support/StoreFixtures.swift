//  WHAT: Packages for the gate tests: the store's own fixtures (MarbleAgent at e7040d5, PlateAgent at 10071ed, as
//        craft.rao.nyc's fixtures.test-data.ts keeps them), folders written from a dictionary, a whole good package
//        for an identity (its listing files written by ListingFiles), and PNGs of any size.

@testable import CraftedForge
import CoreGraphics
import CraftedCore
import Foundation

enum StoreFixtures {
    static let marblePackage = """
    // swift-tools-version:6.0
    // MarbleAgent: a photo filter on the GPU, as a Granite agent package. An app that links it finds the
    // `marble` agent through Granite's roster, with nothing listed by hand.

    import PackageDescription

    let package = Package(
        name: "MarbleAgent",
        platforms: [.macOS(.v14)],
        products: [
            .library(name: "MarbleAgent", targets: ["MarbleAgent"]),
        ],
        dependencies: [
            .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
        ],
        targets: [
            .target(
                name: "MarbleAgent",
                dependencies: [.product(name: "GraniteAgents", package: "Granite")],
                swiftSettings: [.swiftLanguageMode(.v6)]),
            .testTarget(
                name: "MarbleAgentTests",
                dependencies: ["MarbleAgent", .product(name: "GraniteAgents", package: "Granite")],
                swiftSettings: [.swiftLanguageMode(.v6)]),
        ]
    )

    """

    static let platePackage = """
    // swift-tools-version:6.0
    // PlateAgent: an editorial architecture plate of a project's flow, drafted by the host's model, laid out and
    // measured in WebKit, and written as a PNG at 2x, as a Granite agent package. An app that links it finds the
    // `plate` agent through Granite's roster, with nothing listed by hand.

    import PackageDescription

    let package = Package(
        name: "PlateAgent",
        // WebKit's WebPage renders and measures the plate in-process, with no window: macOS 26.
        platforms: [.macOS("26.0")],
        products: [
            .library(name: "PlateAgent", targets: ["PlateAgent"]),
        ],
        dependencies: [
            .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
        ],
        targets: [
            .target(
                name: "PlateAgent",
                dependencies: [.product(name: "GraniteAgents", package: "Granite")],
                resources: [.copy("Resources")],
                swiftSettings: [.swiftLanguageMode(.v6)]),
        ]
    )

    """

    static let plateResolved = """
    {
      "originHash" : "ee91f348c192cabd2378b7df2708ee369ff4cb95fddc9341c597aa15b3055912",
      "pins" : [
        {
          "identity" : "granite",
          "kind" : "remoteSourceControl",
          "location" : "https://github.com/riteshpakala/Granite.git",
          "state" : {
            "branch" : "main",
            "revision" : "e64723f3e3fde412622f369a8ca7766ba2777119"
          }
        }
      ],
      "version" : 3
    }

    """

    static let marbleRecord = """
    import GraniteAgents

    /// Marble's place in Granite's roster: an app that links this package finds the `marble` agent with
    /// `GraniteRoster.discovered()`, with nothing listed by hand.
    @used @section("__DATA_CONST,__granite")
    let marbleRecord: GraniteRoster.Record = { GraniteRoster.record(MarbleAgent.self) }

    """

    static let marbleAgent = """
    import GraniteAgents

    public struct MarbleAgent: GraniteAgentPackage {
        public typealias Output = MarbleResult

        public static let word = "marble"
        public static let summary = "gives a photo a look from its catalog (sepia) on the GPU and writes the result beside it."
    }

    """

    static let mit = """
    MIT License

    Copyright (c) 2026 Ritesh Pakala

    Permission is hereby granted, free of charge, to any person obtaining a copy

    """

    /// A temporary folder holding `files` (relative path → text).
    static func folder(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("crafted-test-\(UUID().uuidString)", isDirectory: true)
        for (path, text) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return root
    }

    static func agentSource(_ identity: AgentIdentity) -> String {
        """
        import GraniteAgents

        public struct \(identity.typeName): GraniteAgentPackage {
            public static let word = "\(identity.word)"
        }

        """
    }

    /// A package the store takes, for `identity`: its listing, icon and LICENSE written as the forge writes them.
    static func goodPackage(_ identity: AgentIdentity) throws -> URL {
        let package = try folder([
            "Package.swift": marblePackage.replacingOccurrences(of: "MarbleAgent", with: identity.package),
            "Package.resolved": plateResolved,
            "README.md": "# \(identity.display)\n\nTotals invoices.\n",
            "Sources/\(identity.agentTarget)/\(identity.base)Record.swift":
                "import GraniteAgents\n\nlet \(identity.recordName): GraniteRoster.Record = { GraniteRoster.record(\(identity.typeName).self) }\n",
            "Sources/\(identity.agentTarget)/\(identity.typeName).swift": agentSource(identity),
            ".gitignore": ".build/\n",
        ])
        let listing = AgentListing(name: identity.display, word: identity.word, tagline: "Totals a folder of invoices.",
                                   category: .data, keywords: ["invoices", "totals"], license: .mit)
        try ListingFiles.write(listing: listing, icon: nil, identity: identity, role: .engineer, into: package)
        return package
    }

    /// A plain PNG of the given size.
    static func png(width: Int, height: Int) throws -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 0.8, green: 0.6, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try IconNormaliser.pngData(context.makeImage()!)
    }
}
