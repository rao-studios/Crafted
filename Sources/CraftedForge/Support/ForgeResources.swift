//  WHAT: Finds the forge's bundled resources (prompts, hazard sheets, licence texts, reserved words, fallback faces).
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
        guard let bundle else { return nil }
        let base = bundle.resourceURL ?? bundle.bundleURL
        for candidate in [base.appendingPathComponent("Resources").appendingPathComponent(path), base.appendingPathComponent(path)] {
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    public static func text(_ path: String) -> String? {
        url(path).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}
