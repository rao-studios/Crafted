import AppKit

/// Finds bundled resources. PIN: never `Bundle.module` inside an .app: SwiftPM's accessor traps when the bundle isn't
/// beside the binary. make-app.sh copies Crafted_CraftedApp.bundle into Contents/Resources; dev builds keep it beside
/// the binary. (The watercolour finds its own files the same way, WatercolourResources.)
enum CraftedAssets {
    private static let bundleName = "Crafted_CraftedApp.bundle"

    static func url(_ name: String, ext: String) -> URL? {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(bundleName),
        ]
        for case let bundleURL? in candidates {
            // .copy("Resources") keeps the folder; a bundle make-app.sh normalised keeps it under Contents/Resources.
            for root in [bundleURL, bundleURL.appendingPathComponent("Contents/Resources")] {
                for folder in ["Resources", ""] {
                    let candidate = (folder.isEmpty ? root : root.appendingPathComponent(folder))
                        .appendingPathComponent("\(name).\(ext)")
                    if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
                }
            }
        }
        return nil
    }

    /// A bare binary (`swift build`'s, as Scripts/dev/dev.sh runs it) has no bundle, so no icon for the Dock to find:
    /// it sets its own (`appIcon(dark:)`). A packaged Crafted never does, so macOS draws the layered icon from Assets.car.
    static var isBareBinary: Bool { Bundle.main.bundleURL.pathExtension != "app" }

    /// The Dock tile a bare binary sets for itself, cream or graphite.
    static func appIcon(dark: Bool) -> NSImage? {
        url(dark ? "AppIcon-dark" : "AppIcon-light", ext: "png").flatMap(NSImage.init(contentsOf:))
    }

    /// Rao's seal, for About.
    static func sealImage() -> NSImage? {
        url("seal", ext: "png").flatMap(NSImage.init(contentsOf:))
    }
}
