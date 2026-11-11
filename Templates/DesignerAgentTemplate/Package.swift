// swift-tools-version: 6.0
// AtelierAgent: Atelier Template as a Craft agent, a Granite agent package. It draws new pieces (posters, flyers,
// brochures, one-pagers, social cards, stories, business cards, slides, banners) in one designer's style. The host's
// model writes a piece as blocks of words; the kit lays them out in WebKit in the style (its colours, type, space,
// shapes, motifs and mark), fits the type, measures what overflowed, and the model cuts until it measures clean. Every
// piece carries a colophon crediting the designer. An app that links the package finds the `atelierword` agent
// through Granite's roster.
//
// AtelierKit is Granite-free: the style, the piece and its blocks, the kit, the layout engines and the WebKit
// renderer, with the style's resources. AtelierAgent is the agent: the wiring, the loop with the host's model, the
// answer.

import PackageDescription

let package = Package(
    name: "AtelierAgent",
    // WebKit's WebPage lays out, measures and exports pieces in-process, with no window: macOS 26.
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "AtelierAgent", targets: ["AtelierAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        // The style (style.json, its cleared fonts, the designer's mark, motifs), found by hand (AtelierResources),
        // never through Bundle.module.
        .target(
            name: "AtelierKit",
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "AtelierAgent",
            dependencies: ["AtelierKit", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        // The kit under very different styles: each format laid out clean at its exact size, in the style's own
        // faces and colours.
        .testTarget(
            name: "AtelierKitTests",
            dependencies: ["AtelierKit"],
            // Read from the source tree (#filePath), never a bundle.
            exclude: ["Fixtures"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        // The agent as a host finds it: its record, its schema, a call drafted, measured and revised.
        .testTarget(
            name: "AtelierAgentTests",
            dependencies: ["AtelierAgent", "AtelierKit", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
