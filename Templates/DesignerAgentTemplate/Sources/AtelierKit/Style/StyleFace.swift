import CoreText
import Foundation

/// One bundled font file as the page loads it: the family the style calls it, the weights it covers (a variable face
/// all of its axis), its style, and the file as a data URL.
public struct StyleFace: Sendable, Equatable {
    public let family: String
    public let weight: String
    public let style: String
    public let source: String

    /// The face in `url`, read with CoreText for its weight and slant; nil when it is not a font.
    public static func read(_ url: URL, family: String) -> StyleFace? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty,
              let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor],
              let descriptor = descriptors.first else { return nil }
        let font = CTFontCreateWithFontDescriptor(descriptor, 16, nil)
        let traits = CTFontCopyTraits(font) as? [CFString: Any] ?? [:]
        let symbolic = (traits[kCTFontSymbolicTrait] as? UInt32) ?? 0
        let italic = symbolic & CTFontSymbolicTraits.traitItalic.rawValue != 0
            || url.lastPathComponent.lowercased().contains("italic")
        var weight = String(cssWeight((traits[kCTFontWeightTrait] as? Double) ?? 0))
        if let axes = CTFontCopyVariationAxes(font) as? [[CFString: Any]] {
            for axis in axes where (axis[kCTFontVariationAxisIdentifierKey] as? Int) == 0x7767_6874 {
                let low = Int((axis[kCTFontVariationAxisMinimumValueKey] as? Double) ?? 100)
                let high = Int((axis[kCTFontVariationAxisMaximumValueKey] as? Double) ?? 900)
                weight = "\(low) \(high)"
            }
        }
        let format: String
        switch url.pathExtension.lowercased() {
        case "otf": format = "opentype"
        case "woff": format = "woff"
        case "woff2": format = "woff2"
        default: format = "truetype"
        }
        let mime = format == "opentype" ? "font/otf" : format == "truetype" ? "font/ttf" : "font/\(format)"
        return StyleFace(family: family, weight: weight, style: italic ? "italic" : "normal",
                         source: "url(\"data:\(mime);base64,\(data.base64EncodedString())\") format(\"\(format)\")")
    }

    /// CoreText's weight trait (-1 to 1) as a CSS weight.
    static func cssWeight(_ trait: Double) -> Int {
        let stops: [(Double, Int)] = [(-0.8, 100), (-0.6, 200), (-0.4, 300), (0, 400), (0.23, 500), (0.3, 600), (0.4, 700), (0.56, 800), (0.62, 900)]
        return stops.min { abs($0.0 - trait) < abs($1.0 - trait) }?.1 ?? 400
    }

    public var css: String {
        "@font-face { font-family: \"\(StyleCSS.familyName(family))\"; font-style: \(style); font-weight: \(weight); font-display: block; src: \(source); }"
    }
}
