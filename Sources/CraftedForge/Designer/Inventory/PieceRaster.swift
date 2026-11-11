//  WHAT: A piece as pixels, whatever it was drawn in: a raster read through ImageIO (a psd's composite too), a PDF page
//        drawn with CoreGraphics, an SVG drawn by AppKit. Bounded on its long side, so the vision model's picture is
//        never larger than it can take and measuring is cheap.
//  PIN:  BOUND EVERY PICTURE. The live vision model ends the process on an oversized picture (the plan's Frigate rules),
//        so nothing it is shown is longer than 1540 px on a side.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum PieceRaster {
    public static let lookSide = 1540

    public static func image(raster url: URL, longSide: Int = lookSide) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: longSide, kCGImageSourceShouldCacheImmediately: true]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    public static func pageCount(pdf url: URL) -> Int {
        CGPDFDocument(url as CFURL)?.numberOfPages ?? 0
    }

    /// A PDF's page (from 1), on white, scaled so its long side is `longSide`.
    public static func image(pdf url: URL, page index: Int, longSide: Int = lookSide) -> CGImage? {
        guard let document = CGPDFDocument(url as CFURL), let page = document.page(at: index) else { return nil }
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = Double(longSide) / Double(max(box.width, box.height))
        let (w, h) = (Int((box.width * scale).rounded()), Int((box.height * scale).rounded()))
        guard let context = canvas(w, h) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }

    /// An SVG as AppKit draws it, scaled so its long side is at most `longSide`.
    public static func image(svg url: URL, longSide: Int = lookSide) -> CGImage? {
        guard let picture = NSImage(contentsOf: url), picture.size.width > 0, picture.size.height > 0 else { return nil }
        let scale = Double(longSide) / Double(max(picture.size.width, picture.size.height))
        let (w, h) = (max(Int(picture.size.width * scale), 1), max(Int(picture.size.height * scale), 1))
        var rect = CGRect(x: 0, y: 0, width: w, height: h)
        guard let image = picture.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        return scaled(image, longSide: longSide)
    }

    /// `image` no longer than `longSide` on its long side (never enlarged).
    public static func scaled(_ image: CGImage, longSide: Int) -> CGImage {
        let long = max(image.width, image.height)
        guard long > longSide else { return image }
        let scale = Double(longSide) / Double(long)
        let (w, h) = (max(Int(Double(image.width) * scale), 1), max(Int(Double(image.height) * scale), 1))
        guard let context = canvas(w, h) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return context.makeImage() ?? image
    }

    /// RGBA bytes of `image` drawn at most `side` on its long side, over white.
    public static func rgba(_ image: CGImage, side: Int) -> (pixels: [UInt8], width: Int, height: Int) {
        let small = scaled(image, longSide: side)
        let (w, h) = (small.width, small.height)
        var pixels = [UInt8](repeating: 255, count: w * h * 4)
        if let context = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
            context.draw(small, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return (pixels, w, h)
    }

    public static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    static func canvas(_ w: Int, _ h: Int) -> CGContext? {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}
