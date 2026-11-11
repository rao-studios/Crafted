// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextStats",
    products: [.library(name: "TextStats", targets: ["TextStats"])],
    targets: [
        .target(name: "TextStats"),
        .testTarget(name: "TextStatsTests", dependencies: ["TextStats"]),
    ]
)
