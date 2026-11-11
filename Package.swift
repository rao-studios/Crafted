// swift-tools-version: 6.1
// WHAT: Crafted, one SwiftPM package. A person drops a folder; two on-device models prepare a Craft agent (a Swift
//       package on Granite's `granite-agent/1`) they download as a zip, ready to push for the Craft Agent Store.
// OUT:  Targets by layer:
//       CraftedCore      the vocabulary: roles, the two models, naming, the listing and its rules, generations on
//                        disk, export. No dependencies.
//       CraftedMLX       the only target that names Frigate: the model home, download, and the one-resident runtime.
//       CraftedForge     the pipeline: folder in, package out. No UI, no MLX, no Granite: it talks to a model and a
//                        toolchain through seams, so every stage runs on scripted stand-ins in tests.
//       CraftedToolchain the live toolchain seam: swift build / test, and Granite's installer for the real install gate.
//       CraftedRuntime   the Granite services (models, preferences, the library of generations, the forge) and the
//                        runtime root that wires the seams.
//       CraftedApp       the Mac app: a Granite component per page. Never imports CraftedMLX.
//       crafted-check    a headless runner: a forge end to end from the terminal (scripted models now, real later).
// PIN:  EVERY DEPENDENCY IS A URL. Frigate and Granite on branch main, Package.resolved holding the commits (started
//       from Craft's, so both apps build the same MLX stack).
// PIN:  Platform is macOS "27.0" and Support/Info.plist says the same. Every target builds in Swift 5 language mode,
//       as Craft: MLXArray is not Sendable, and a relay inside a reducer needs it (Granite rule 9).
// PIN:  The app product is CraftedApp; make-app.sh names the .app's executable Crafted.

import PackageDescription

let swift5: [SwiftSetting] = [.swiftLanguageMode(.v5)]
let granite: [Target.Dependency] = [
    .product(name: "Granite", package: "Granite"),
    .product(name: "GraniteAgents", package: "Granite"),
]
func frigate(_ name: String) -> Target.Dependency { .product(name: name, package: "Frigate") }

let package = Package(
    name: "Crafted",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "CraftedApp", targets: ["CraftedApp"]),
        .executable(name: "crafted-check", targets: ["CraftedCheck"]),
        .library(name: "CraftedCore", targets: ["CraftedCore"]),
        .library(name: "CraftedForge", targets: ["CraftedForge"]),
    ],
    dependencies: [
        // The MLX stack every Rao app runs: mlx-swift, mlx-swift-lm (LLM and VLM), swift-transformers' Hub.
        .package(url: "https://github.com/rao-studios/Frigate.git", branch: "main"),
        // Components, services, relays; and GraniteAgents: the scaffolding, the agent standard, the installer.
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        .target(name: "CraftedCore", swiftSettings: swift5),
        .target(
            name: "CraftedMLX",
            dependencies: [
                "CraftedCore",
                frigate("MLX"), frigate("MLXLLM"), frigate("MLXVLM"), frigate("MLXLMCommon"), frigate("FrigateBridge"),
            ],
            swiftSettings: swift5
        ),
        .target(
            name: "CraftedForge",
            dependencies: ["CraftedCore"],
            // Prompts, hazard sheets, licence texts, reserved words, fallback faces. Found by hand
            // (ForgeResources), never Bundle.module, which crashes inside a .app.
            resources: [.copy("Resources")],
            swiftSettings: swift5
        ),
        .target(
            name: "CraftedToolchain",
            dependencies: ["CraftedForge", "CraftedCore", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: swift5
        ),
        .target(
            name: "CraftedRuntime",
            dependencies: ["CraftedCore", "CraftedMLX", "CraftedForge", "CraftedToolchain"] + granite,
            swiftSettings: swift5
        ),
        .executableTarget(
            name: "CraftedApp",
            dependencies: ["CraftedRuntime", "CraftedForge", "CraftedCore"] + granite,
            resources: [.copy("Resources")],
            swiftSettings: swift5,
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "\(Context.packageDirectory)/Support/Info.plist",
                ]),
            ]
        ),
        .executableTarget(
            name: "CraftedCheck",
            dependencies: ["CraftedCore", "CraftedMLX", "CraftedForge", "CraftedToolchain"],
            swiftSettings: swift5
        ),
        .testTarget(name: "CraftedCoreTests", dependencies: ["CraftedCore"], swiftSettings: swift5),
        .testTarget(name: "CraftedForgeTests", dependencies: ["CraftedForge", "CraftedCore"], swiftSettings: swift5),
    ]
)
