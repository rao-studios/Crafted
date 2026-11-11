// swift-tools-version: 6.0
// SkeletonAgent: Skeleton Template as a Craft agent, a Granite agent package. A call names a command and its
// arguments (or says what it wants, and the host's model picks the command); the router reads the arguments, runs
// the ported logic in SkeletonCore, and writes what it made as files, Canvas pictures and series, or a hand-off for
// the next agent. An app that links the package finds the `skeletonword` agent through Granite's roster.
//
// SkeletonCore is Foundation only: the logic and its data, buildable and testable on its own. SkeletonAgent is the
// agent: the wiring, the router, the emitters and the report kit.

import PackageDescription

let package = Package(
    name: "SkeletonAgent",
    // WebKit's WebPage draws reports to PNG and PDF in-process, with no window: macOS 26.
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "SkeletonAgent", targets: ["SkeletonAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        // The logic and the tables it reads. Found by hand (CoreResources), never through Bundle.module.
        .target(
            name: "SkeletonCore",
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "SkeletonAgent",
            dependencies: ["SkeletonCore", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        // Every unit's vectors, called from JSON.
        .testTarget(
            name: "SkeletonCoreTests",
            dependencies: ["SkeletonCore"],
            exclude: ["Vectors"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        // The agent as a host finds it: its record, its schema, and every command's canonical call.
        .testTarget(
            name: "SkeletonAgentTests",
            dependencies: ["SkeletonAgent", "SkeletonCore", .product(name: "GraniteAgents", package: "Granite")],
            exclude: ["Calls"],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
