//  WHAT: Finds the forge's bundled resources (prompts, hazard sheets, licence texts, reserved words, fallback faces).
//  IN:   `CRAFTED_FORGE_RESOURCES` (a Resources folder, for a tool run outside the build), else the
//        Crafted_CraftedForge.bundle beside the app, the executable or the test bundle.
//  PIN:  NEVER `Bundle.module`: SwiftPM's accessor traps inside a .app when the bundle is not where the build left
//        it. make-app.sh copies Crafted_CraftedForge.bundle into Contents/Resources; a dev binary and the test
//        runner keep it beside them.

import Foundation

public enum ForgeResources {
    static let bundleName = "Crafted_CraftedForge.bundle"

    private final class Token {}

    public static var bundle: Bundle? {
        var candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(bundleName),
        ]
        let own = Bundle(for: Token.self).bundleURL
        candidates.append(own.deletingLastPathComponent().appendingPathComponent(bundleName))
        candidates.append(own.appendingPathComponent(bundleName))
        for case let url? in candidates {
            if let bundle = Bundle(url: url) { return bundle }
        }
        return nil
    }

    /// A resource by its path under Resources/: "Prompts/engineer.card.v1.md".
    public static func url(_ path: String) -> URL? {
        var bases: [URL] = []
        if let override = ProcessInfo.processInfo.environment["CRAFTED_FORGE_RESOURCES"], !override.isEmpty {
            bases.append(URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true))
        }
        if let bundle {
            let base = bundle.resourceURL ?? bundle.bundleURL
            bases += [base.appendingPathComponent("Resources"), base]
        }
        for base in bases {
            let candidate = base.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    public static func text(_ path: String) -> String? {
        url(path).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}
