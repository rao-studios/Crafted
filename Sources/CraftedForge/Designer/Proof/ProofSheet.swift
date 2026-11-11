//  WHAT: The proof sheet: every format the built agent drew, side by side on one PNG with its name under it, so the
//        designer sees their style across formats at a glance, and the README shows it.
//  IN:   The proof PNGs the install gate's calls wrote.
//  OUT:  artefacts/proof-sheet.png → the package's Assets/proof.png.

import CoreGraphics
import CoreText
import Foundation
import ImageIO

public enum ProofSheet {
    /// The sheet of `pictures` (name, file), rows `rowHeight` tall, at most `width` wide; nil when none reads.
    public static func compose(_ pictures: [(name: String, url: URL)], width: Double = 2400, rowHeight: Double = 520) -> Data? {
        let images: [(String, CGImage)] = pictures.compactMap { name, url in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                                             kCGImageSourceThumbnailMaxPixelSize: 1400] as CFDictionary) else { return nil }
            return (name, image)
        }
        guard !images.isEmpty else { return nil }
        let gap = 40.0, label = 44.0
        // Rows filled left to right, each picture at the row's height.
        var rows: [[(String, CGImage, Double)]] = [[]]
        var used = gap
        for (name, image) in images {
            let w = Double(image.width) * rowHeight / Double(image.height)
            if used + w + gap > width, !rows[rows.count - 1].isEmpty { rows.append([]); used = gap }
            rows[rows.count - 1].append((name, image, min(w, width - 2 * gap)))
            used += w + gap
        }
        let height = gap + Double(rows.count) * (rowHeight + label + gap)
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(srgbRed: 0.93, green: 0.92, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 22, nil)
        for (r, row) in rows.enumerated() {
            var x = gap
            let top = height - gap - Double(r) * (rowHeight + label + gap)
            for (name, image, w) in row {
                let h = w * Double(image.height) / Double(image.width)
                context.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: CGColor(gray: 0, alpha: 0.18))
                context.draw(image, in: CGRect(x: x, y: top - h, width: w, height: h))
                context.setShadow(offset: .zero, blur: 0, color: nil)
                let text = NSAttributedString(string: name, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                                                                        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.25, alpha: 1)])
                context.textPosition = CGPoint(x: x, y: top - h - 32)
                CTLineDraw(CTLineCreateWithAttributedString(text), context)
                x += w + gap
            }
        }
        guard let image = context.makeImage() else { return nil }
        return PieceRaster.png(image)
    }
}
