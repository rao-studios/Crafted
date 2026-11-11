//  WHAT: Finds the watercolour's files in the app's resource bundle: the layers and blooms (Watercolour/), the arrival
//        maps (washes/), the wash's metallib, the glyph and the seal.
//  IN:   A path under Sources/CraftedApp/Resources: "Watercolour/gardens-far.webp", "Watercolour.metallib".
//  OUT:  The file's URL, or nil when the bundle or the file is missing (callers fall back: paper, a crossfade).
//  PIN:  NEVER `Bundle.module`: SwiftPM's accessor traps inside a .app when the bundle is not where the build left it.
//        make-app.sh copies Crafted_CraftedApp.bundle into Contents/Resources; a dev binary keeps it beside itself.
//        `.copy("Resources")` keeps the folder, so a file sits under Resources/ inside the bundle.

import Foundation

enum WatercolourResources {
    static let bundleName = "Crafted_CraftedApp.bundle"

    /// The first resource bundle found: inside an .app, beside the .app's executable, beside a bare binary.
    static let bundleURL: URL? = {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(bundleName),
        ]
        var isFolder: ObjCBool = false
        for case let url? in candidates where FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue {
            return url
        }
        return nil
    }()

    static func url(_ path: String) -> URL? {
        guard let base = bundleURL else { return nil }
        let inBundle = Bundle(url: base)?.resourceURL ?? base
        for root in [inBundle, base] {
            for candidate in [root.appendingPathComponent("Resources").appendingPathComponent(path), root.appendingPathComponent(path)]
            where FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
