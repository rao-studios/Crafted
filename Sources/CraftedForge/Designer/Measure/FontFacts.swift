//  WHAT: What a font file says of itself, read with CoreText: its family, style, weight and slant, its class (serif,
//        sans, slab, mono, script, display), and its licence from the name table (ID 13, the licence; ID 14, its URL)
//        or a licence file beside it. Whether that licence lets the face ship is decided here, by its words.
//  OUT:  Rights (a decision per family), reconcile (bundled faces and their licences), NOTICE.

import CoreText
import Foundation

public struct FontFact: Codable, Sendable, Equatable {
    /// The file, relative to the dropped folder.
    public var path: String
    public var family: String
    public var style: String
    public var postScript: String
    public var weight: Int
    public var italic: Bool
    /// serif, sans, slab, mono, script, display.
    public var `class`: String
    /// The name table's licence (ID 13) and its URL (ID 14).
    public var licenceText: String?
    public var licenceURL: String?
    /// A licence file beside the font, relative to the folder.
    public var licenceFile: String?
    /// OFL-1.1, Apache-2.0, UFL-1.0, open (another open licence), or nil when nothing says it may ship.
    public var openLicence: String?

    /// Every face in `url` (a .ttc holds several).
    public static func read(_ url: URL, path: String, folder: URL) -> [FontFact] {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return [] }
        let beside = licenceFile(near: url, folder: folder)
        return descriptors.map { descriptor in
            let font = CTFontCreateWithFontDescriptor(descriptor, 16, nil)
            let family = (CTFontCopyName(font, kCTFontFamilyNameKey) as String?) ?? url.deletingPathExtension().lastPathComponent
            let style = (CTFontCopyName(font, kCTFontStyleNameKey) as String?) ?? "Regular"
            let traits = CTFontCopyTraits(font) as? [CFString: Any] ?? [:]
            let symbolic = (traits[kCTFontSymbolicTrait] as? UInt32) ?? 0
            let weight = (traits[kCTFontWeightTrait] as? Double) ?? 0
            let licence = CTFontCopyName(font, kCTFontLicenseNameKey) as String?
            let licenceURL = CTFontCopyName(font, kCTFontLicenseURLNameKey) as String?
            let fileText = beside.flatMap { try? String(contentsOf: folder.appendingPathComponent($0), encoding: .utf8) }
            return FontFact(path: path, family: family, style: style, postScript: CTFontCopyPostScriptName(font) as String,
                            weight: cssWeight(weight), italic: symbolic & CTFontSymbolicTraits.traitItalic.rawValue != 0,
                            class: fontClass(symbolic, family: family), licenceText: licence, licenceURL: licenceURL, licenceFile: beside,
                            openLicence: openLicence([licence, licenceURL, fileText].compactMap { $0 }.joined(separator: "\n")))
        }
    }

    /// The open licence `text` names, if any.
    public static func openLicence(_ text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("open font license") || lower.contains("scripts.sil.org/ofl") || lower.contains("openfontlicense.org") { return "OFL-1.1" }
        if lower.contains("apache license") || lower.contains("apache.org/licenses") { return "Apache-2.0" }
        if lower.contains("ubuntu font licence") { return "UFL-1.0" }
        if lower.contains("gust font license") || lower.contains("bitstream vera") || lower.contains("creative commons zero") || lower.contains("cc0") { return "open" }
        return nil
    }

    /// OFL.txt, LICENSE.txt, or any text file beside the font that names a licence.
    static func licenceFile(near url: URL, folder: URL) -> String? {
        let dir = url.deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let base = folder.standardizedFileURL.resolvingSymlinksInPath().path
        for name in names.sorted() {
            let upper = name.uppercased()
            guard upper.hasPrefix("OFL") || upper.contains("LICENSE") || upper.contains("LICENCE") || upper.hasPrefix("COPYING") else { continue }
            let full = dir.appendingPathComponent(name).standardizedFileURL.resolvingSymlinksInPath().path
            return String(full.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return nil
    }

    static func cssWeight(_ trait: Double) -> Int {
        let stops: [(Double, Int)] = [(-0.8, 100), (-0.6, 200), (-0.4, 300), (0, 400), (0.23, 500), (0.3, 600), (0.4, 700), (0.56, 800), (0.62, 900)]
        return stops.min { abs($0.0 - trait) < abs($1.0 - trait) }?.1 ?? 400
    }

    static func fontClass(_ symbolic: UInt32, family: String) -> String {
        if symbolic & CTFontSymbolicTraits.traitMonoSpace.rawValue != 0 { return "mono" }
        let cls = (symbolic & CTFontSymbolicTraits.traitClassMask.rawValue) >> 28
        switch cls {
        case 1, 2, 3, 7: return "serif"
        case 4: return "slab"
        case 8: return "sans"
        case 9: return "display"
        case 10: return "script"
        default:
            let lower = family.lowercased()
            if lower.contains("mono") || lower.contains("code") { return "mono" }
            if lower.contains("serif") && !lower.contains("sans") { return "serif" }
            if ["playfair", "garamond", "caslon", "bodoni", "didot", "baskerville", "times", "georgia"].contains(where: lower.contains) { return "serif" }
            return "sans"
        }
    }
}
