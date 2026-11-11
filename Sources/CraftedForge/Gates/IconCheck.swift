//  WHAT: Whether Assets/icon.png is an icon the store takes: a PNG, square, 512 px or more on a side, 6 MB at most.
//  IN:   craft.rao.nyc app/(store)/_lib/source/snapshot.ts (ICON_MAX_BYTES, 6 MB) and image.ts (ICON_SIZE, 512: what
//        every page draws it at); the README's "square, 512 px or more".
//  OUT:  StoreValidator; ListingFiles checks the icon it writes the same way.

import Foundation
import ImageIO

public enum IconCheck {
    public static let path = "Assets/icon.png"
    public static let maxBytes = 6 * 1024 * 1024
    public static let minSide = 512
    static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// Why the PNG data is not an icon the store takes, one sentence each with its fix; empty when it is.
    public static func problems(_ data: Data) -> [String] {
        guard data.count <= maxBytes else {
            return ["\(path) is \(data.count / 1_048_576) MB; the store reads one of 6 MB at most: save it smaller (1024 px is plenty)."]
        }
        guard Array(data.prefix(8)) == pngSignature else {
            return ["\(path) is not a PNG: save the icon as PNG."]
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return ["\(path) does not read as a picture: save it again as a PNG."]
        }
        var problems: [String] = []
        if width != height { problems.append("\(path) is \(width)×\(height); the store's icon is square: crop it to a square.") }
        if min(width, height) < minSide {
            problems.append("\(path) is \(min(width, height)) px on its short side; the store needs \(minSide) px or more: use a larger picture.")
        }
        return problems
    }

    /// The same, for the icon in a package folder; a missing icon is a problem.
    public static func problems(inPackage package: URL) -> [String] {
        guard let data = try? Data(contentsOf: package.appendingPathComponent(path)) else {
            return ["There is no \(path): add a square PNG of \(minSide) px or more (Crafted paints one when you give none)."]
        }
        return problems(data)
    }
}
