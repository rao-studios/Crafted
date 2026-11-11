import Foundation

/// The package's own style, found where its resource bundle was copied: beside the app's resources, beside the
/// executable (an installed runner, a test bundle), or where `STYLE_RESOURCES` points. (After PlateAgent's
/// PlateResources.)
///
/// PIN: NEVER `Bundle.module`. Its accessor ends the process when the bundle is not where the build put it; an
/// installed runner keeps its bundles beside it, and an app that forgot to copy one gets an error that says where it
/// looked.
public enum AtelierResources {
    public static let bundleName = "AtelierAgent_AtelierKit.bundle"

    /// The package's style, read from its bundle.
    public static func book() throws -> StyleBook {
        let places = directories()
        guard let folder = styleFolder(in: places) else { throw PieceError.resources(tried: places.map(\.path)) }
        return try StyleBook.load(folder: folder)
    }

    /// The Style folder inside the first bundle that holds one.
    static func styleFolder(in places: [URL]) -> URL? {
        let manager = FileManager.default
        for place in places where manager.fileExists(atPath: place.path) {
            for candidate in ["Resources/Style", "Contents/Resources/Resources/Style", "Contents/Resources/Style", "Style", ""] {
                let folder = place.appendingPathComponent(candidate)
                if manager.fileExists(atPath: folder.appendingPathComponent("style.json").path) { return folder }
            }
        }
        return nil
    }

    /// Where the bundle may be, in the order it is looked for.
    static func directories() -> [URL] {
        var places: [URL] = []
        if let override = ProcessInfo.processInfo.environment["STYLE_RESOURCES"], !override.isEmpty {
            places.append(URL(fileURLWithPath: (override as NSString).expandingTildeInPath))
        }
        let main = Bundle.main
        var homes: [URL] = [main.resourceURL, main.bundleURL].compactMap { $0 }
        if let executable = main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent() {
            homes.append(executable)
            homes.append(executable.deletingLastPathComponent().appendingPathComponent("Resources"))
        }
        homes.append(Bundle(for: Token.self).bundleURL.deletingLastPathComponent())
        for home in homes {
            let bundle = home.appendingPathComponent(bundleName)
            if !places.contains(bundle) { places.append(bundle) }
        }
        return places
    }

    /// A class of this module's own, for the bundle its code was loaded from.
    private final class Token {}
}
