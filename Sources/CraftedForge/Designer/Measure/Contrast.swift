//  WHAT: WCAG contrast between two colours, and the nearest colour to one that reaches a contrast against another:
//        its OKLab lightness moved toward black or white, hue and chroma kept, so an adjusted ink is still the
//        designer's ink, only darker or lighter.

import Foundation

public enum Contrast {
    public static func luminance(_ hex: String) -> Double {
        guard let (r, g, b) = OKLab.rgb(hex) else { return 0 }
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    public static func ratio(_ a: String, _ b: String) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// `colour` moved in lightness, the least it must, to reach `target` against `ground`; itself when it already
    /// does. The direction is away from the ground: darker on a light ground, lighter on a dark one.
    public static func adjusted(_ colour: String, against ground: String, target: Double) -> String {
        guard ratio(colour, ground) < target, let start = OKLab(hex: colour) else { return OKLab.normal(colour) ?? colour }
        let darker = luminance(ground) > 0.18
        var lab = start
        for _ in 0..<100 {
            lab.l = darker ? max(lab.l - 0.01, 0) : min(lab.l + 0.01, 1)
            // Near black or white a colour cannot keep its chroma in gamut: let it go grey as it gets there.
            if lab.l < 0.12 || lab.l > 0.95 { lab.a *= 0.85; lab.b *= 0.85 }
            if ratio(lab.hex, ground) >= target { return lab.hex }
        }
        return darker ? "#000000" : "#FFFFFF"
    }
}
