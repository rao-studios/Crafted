//  WHAT: The icon a package carries when the person gave none: a 1024 px tile of Rao's paper, a ring of French knots
//        in brass on a squircle at 90% of the tile (as Craft's app icon ties them), and the agent's initials centred
//        in a serif, in ink. A faint wash of colour, its hue from the word, tells two painted tiles apart.
//  IN:   The agent's identity. Craft's Scripts/art/gen-app-icon.swift for the ring: a superellipse of exponent 5,
//        knots about 26 px apart along it by length (not angle, which crowds the corners) and 6 px across.
//  OUT:  ListingFiles (Assets/icon.png). Deterministic: the same identity paints the same bytes' picture.

import CoreGraphics
import CoreText
import CraftedCore
import Foundation

public enum DefaultIcon {
    public static let side = 1024
    static let paper = (0xFD, 0xFB, 0xF4)
    static let brass = (0xAE, 0x90, 0x60)
    static let ink = (0x37, 0x35, 0x2F)
    static let ring = 0.9, knotSpacing = 26.0, knotRadius = 6.0
    /// Serif families, best first; the first this Mac has is used.
    static let serifs = ["New York", "Iowan Old Style", "Charter", "Georgia", "Times New Roman"]

    /// The painted tile as PNG.
    public static func png(for identity: AgentIdentity) throws -> Data {
        guard let image = image(initials: initials(identity.display), hue: hue(identity.word)) else {
            throw ForgeError.stage("Icon", "the default icon could not be drawn")
        }
        return try IconNormaliser.pngData(image)
    }

    /// "Invoice Totals" → "IT"; "Marble" → "M"; up to two, from the first two words.
    public static func initials(_ display: String) -> String {
        let words = display.split(whereSeparator: { !($0.isLetter || $0.isNumber) })
        let letters = words.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }
        return letters.isEmpty ? "C" : letters.joined()
    }

    /// A stable hue, 0 to 1, from the word (FNV-1a: the same in every process, unlike `hashValue`).
    static func hue(_ word: String) -> Double {
        var hash: UInt32 = 2_166_136_261
        for byte in word.utf8 { hash = (hash ^ UInt32(byte)) &* 16_777_619 }
        return Double(hash % 360) / 360
    }

    static func image(initials: String, hue: Double) -> CGImage? {
        let size = Double(side)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Paper, and a faint wash of the word's hue pooled in the middle.
        context.setFillColor(color(paper))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let wash = hsb(hue, 0.30, 0.95)
        if let gradient = CGGradient(colorsSpace: space, colors: [wash.copy(alpha: 0.22)!, wash.copy(alpha: 0)!] as CFArray,
                                     locations: [0, 1]) {
            let centre = CGPoint(x: size / 2, y: size / 2)
            context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: size * 0.48, options: [])
        }
        // The ring of knots.
        context.setFillColor(color(brass, alpha: 0.75))
        let ringSide = size * ring
        let offset = (size - ringSide) / 2
        for knot in along(ringSide, knotSpacing) {
            context.fillEllipse(in: CGRect(x: knot.x + offset - knotRadius, y: knot.y + offset - knotRadius,
                                           width: knotRadius * 2, height: knotRadius * 2))
        }
        // The initials, centred by their drawn bounds.
        drawInitials(initials, in: context, size: size)
        return context.makeImage()
    }

    static func drawInitials(_ text: String, in context: CGContext, size: Double) {
        var points = text.count > 1 ? 380.0 : 460.0
        var line = makeLine(text, points: points)
        var bounds = CTLineGetImageBounds(line, context)
        let widest = size * 0.58
        if bounds.width > widest {
            points *= widest / bounds.width
            line = makeLine(text, points: points)
            bounds = CTLineGetImageBounds(line, context)
        }
        context.textPosition = CGPoint(x: (size - bounds.width) / 2 - bounds.minX, y: (size - bounds.height) / 2 - bounds.minY)
        CTLineDraw(line, context)
    }

    static func makeLine(_ text: String, points: Double) -> CTLine {
        let font = serif(points)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(ink),
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    static func serif(_ points: Double) -> CTFont {
        for family in serifs {
            let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
            let font = CTFontCreateWithFontDescriptor(descriptor, points, nil)
            if (CTFontCopyFamilyName(font) as String) == family { return font }
        }
        return CTFontCreateWithName("Times-Roman" as CFString, points, nil)
    }

    /// The point at angle `t` on a superellipse of exponent `n` filling a `side` square.
    static func squircle(_ side: Double, _ t: Double, _ n: Double = 5) -> (x: Double, y: Double) {
        let r = side / 2, c = cos(t), s = sin(t)
        return (r + r * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n), r + r * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n))
    }

    /// Points around a `side` squircle, evenly spaced by length, about `spacing` apart and closing evenly.
    static func along(_ side: Double, _ spacing: Double, samples: Int = 4096) -> [(x: Double, y: Double)] {
        let points = (0...samples).map { squircle(side, Double($0) / Double(samples) * 2 * .pi) }
        var lengths = [0.0]
        for i in 1...samples { lengths.append(lengths[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)) }
        let total = lengths[samples]
        let count = Int((total / spacing).rounded())
        var out: [(x: Double, y: Double)] = []
        var j = 0
        for k in 0..<count {
            let d = Double(k) / Double(count) * total
            while lengths[j + 1] < d { j += 1 }
            let f = (d - lengths[j]) / (lengths[j + 1] - lengths[j])
            out.append((points[j].x + (points[j + 1].x - points[j].x) * f, points[j].y + (points[j + 1].y - points[j].y) * f))
        }
        return out
    }

    static func color(_ rgb: (Int, Int, Int), alpha: Double = 1) -> CGColor {
        CGColor(srgbRed: Double(rgb.0) / 255, green: Double(rgb.1) / 255, blue: Double(rgb.2) / 255, alpha: alpha)
    }

    static func hsb(_ h: Double, _ s: Double, _ b: Double) -> CGColor {
        let i = Int(h * 6) % 6, f = h * 6 - Double(Int(h * 6))
        let p = b * (1 - s), q = b * (1 - f * s), t = b * (1 - (1 - f) * s)
        let (r, g, bl): (Double, Double, Double) = [(b, t, p), (q, b, p), (p, b, t), (p, q, b), (t, p, b), (b, p, q)][i]
        return CGColor(srgbRed: r, green: g, blue: bl, alpha: 1)
    }
}
