//  WHAT: Colour in OKLab (Björn Ottosson, 2020): a space where a step is the same size to the eye wherever it is
//        taken, so k-means, "near" and "the same colour" mean what a designer means by them. sRGB in and out.

import Foundation

public struct OKLab: Codable, Sendable, Equatable, Hashable {
    public var l: Double
    public var a: Double
    public var b: Double

    public init(l: Double, a: Double, b: Double) { self.l = l; self.a = a; self.b = b }

    /// From sRGB, each 0…1.
    public init(r: Double, g: Double, b blue: Double) {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let (lr, lg, lb) = (linear(r), linear(g), linear(blue))
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        self.l = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        self.a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        self.b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    }

    public init?(hex: String) {
        guard let (r, g, b) = OKLab.rgb(hex) else { return nil }
        self.init(r: r, g: g, b: b)
    }

    /// Back to sRGB, clipped to the gamut.
    public var rgb: (r: Double, g: Double, b: Double) {
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let (lc, mc, sc) = (l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_)
        let r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc
        func gamma(_ c: Double) -> Double {
            let v = min(max(c, 0), 1)
            return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
        }
        return (gamma(r), gamma(g), gamma(bl))
    }

    public var hex: String {
        let (r, g, b) = rgb
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    /// How colourful: the distance from grey.
    public var chroma: Double { (a * a + b * b).squareRoot() }

    /// The distance between two colours (ΔE in OKLab: about 0.02 is a just-noticeable step).
    public func distance(_ other: OKLab) -> Double {
        let (dl, da, db) = (l - other.l, a - other.a, b - other.b)
        return (dl * dl + da * da + db * db).squareRoot()
    }

    /// "#abc", "#AABBCC", "abc" → sRGB 0…1.
    public static func rgb(_ hex: String) -> (Double, Double, Double)? {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
        guard text.count == 6, text.allSatisfy(\.isHexDigit), let value = UInt32(text, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// "#AABBCC", upper case, or nil when it is not a colour.
    public static func normal(_ hex: String) -> String? { OKLab(hex: hex)?.hex }
}
