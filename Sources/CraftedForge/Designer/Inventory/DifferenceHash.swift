//  WHAT: A picture's difference hash: 9 × 8 grey cells, one bit per neighbour pair (is the left one brighter?). Two
//        pieces whose hashes differ in a few bits are the same design exported twice, resized or recompressed.

import CoreGraphics
import Foundation

public enum DifferenceHash {
    /// The 64-bit hash of `image`.
    public static func hash(_ image: CGImage) -> UInt64 {
        let (w, h) = (9, 8)
        var grey = [UInt8](repeating: 0, count: w * h)
        guard let context = CGContext(data: &grey, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return 0 }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var value: UInt64 = 0
        for y in 0..<h {
            for x in 0..<(w - 1) {
                value <<= 1
                if grey[y * w + x] > grey[y * w + x + 1] { value |= 1 }
            }
        }
        return value
    }

    public static func distance(_ a: UInt64, _ b: UInt64) -> Int { (a ^ b).nonzeroBitCount }

    /// At most this many bits apart is one design.
    public static let sameDesign = 5
}
