//  WHAT: A picture as the vision model is shown it: decoded by ImageIO with its EXIF orientation applied, drawn into
//        sRGB RGBA8, and no larger than 1540 px on its long side (never enlarged).
//  IN:   A file or PNG bytes from the forge's `look`.
//  OUT:  MLXModelRuntime.look.
//  PIN:  WE BOUND IT, NOT THE PROCESSOR. ChatSession shrinks every picture to 512×512 by default; the runtime passes
//        `Processing(resize: nil)` and bounds here instead, so a poster keeps its type legible.
//  PIN:  EVERY PICTURE IS BOUNDED. Mistral3VLM has fatalError paths on oversized inputs, and MLX's error handler exits
//        the process: nothing reaches the model unbounded.
//  PIN:  Decoded the way Sewn's LocalVision decodes (ImageIO, oriented, sRGB), never handed to CoreImage as
//        compressed bytes.

import CoreGraphics
import CoreImage
import Foundation
import ImageIO

enum PictureBounds {
    /// The long side a picture reaches the model at.
    static let maxLongSide = 1540

    enum Failure: Error, LocalizedError {
        case unreadable
        var errorDescription: String? { "The picture could not be read." }
    }

    static func bounded(file url: URL) throws -> CIImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw Failure.unreadable }
        return try bounded(source)
    }

    static func bounded(data: Data) throws -> CIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw Failure.unreadable }
        return try bounded(source)
    }

    /// The thumbnail call applies the orientation and bounds the long side in one decode.
    static func bounded(_ source: CGImageSource) throws -> CIImage {
        guard CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0
        else { throw Failure.unreadable }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(max(width, height), maxLongSide),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let oriented = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let drawn = sRGB(oriented)
        else { throw Failure.unreadable }
        return CIImage(cgImage: drawn)
    }

    private static func sRGB(_ image: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
