//  WHAT: The tables, templates and samples the port carries (Resources/), found where the package's resource bundle
//        was copied: beside the app's resources, beside the executable (an installed runner, a test bundle), or where
//        `CORE_RESOURCES` points.
//  OUT:  Logic units that read a carried table; the agent's CommandKit (`kit.resource`).
//  PIN:  NEVER `Bundle.module`. Its accessor ends the process when the bundle is not where the build put it, and an
//        installer copies bundles beside the runner as <Package>_<Target>.bundle; a missing table must be an error a
//        call can say, not a crash.

import Foundation

public enum CoreResources {
    static let bundleName = "SkeletonAgent_SkeletonCore.bundle"

    /// A carried file's bytes, by its name under Resources/.
    public static func data(_ name: String) throws -> Data {
        let places = directories()
        guard let url = find(name, in: places), let data = try? Data(contentsOf: url) else {
            throw CoreFailure.missingResource(name, tried: places.map(\.path))
        }
        return data
    }

    /// A carried text file.
    public static func text(_ name: String) throws -> String {
        String(decoding: try data(name), as: UTF8.self)
    }

    /// A carried JSON file, decoded.
    public static func json<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: try data(name))
        } catch let failure as CoreFailure {
            throw failure
        } catch {
            throw CoreFailure.invalid("The carried table \(name) did not read: \(error)")
        }
    }

    /// Where the bundle may be, in the order it is looked for.
    static func directories() -> [URL] {
        var places: [URL] = []
        if let override = ProcessInfo.processInfo.environment["CORE_RESOURCES"], !override.isEmpty {
            places.append(URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true))
        }
        let main = Bundle.main
        var homes: [URL] = [main.resourceURL, main.bundleURL].compactMap { $0 }
        if let executable = main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent() {
            homes.append(executable)
            homes.append(executable.deletingLastPathComponent().appendingPathComponent("Resources"))
        }
        let own = Bundle(for: Token.self).bundleURL
        homes.append(own.deletingLastPathComponent())
        homes.append(own)
        for home in homes {
            let bundle = home.appendingPathComponent(bundleName)
            if !places.contains(bundle) { places.append(bundle) }
        }
        return places
    }

    /// `name` inside any of `places`, at whichever depth the bundle keeps it.
    static func find(_ name: String, in places: [URL]) -> URL? {
        let manager = FileManager.default
        for place in places where manager.fileExists(atPath: place.path) {
            for candidate in [place.appendingPathComponent(name), place.appendingPathComponent("Resources/\(name)"),
                              place.appendingPathComponent("Contents/Resources/\(name)"),
                              place.appendingPathComponent("Contents/Resources/Resources/\(name)")]
            where manager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// A class of this module's own, for the bundle its code was loaded from.
    private final class Token {}
}
