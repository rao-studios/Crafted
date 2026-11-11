//  WHAT: What code measures of one piece, with no model: its palette (k-means in OKLab, by area), its ground (light,
//        dark, colour, photo), its margins and how much of it is ink, and the corners that hold a small mark.
//  OUT:  DesignMeasures (the folder's palette, grounds, margins), the look prompt (the palette's letters), rights
//        (corner marks).
//  PIN:  CACHED BY CONTENT. Kept in the shared cache under the piece's sha256 and this measure's version, so a piece in
//        two folders is measured once.

import CoreGraphics
import Foundation

public struct PieceMeasure: Codable, Sendable, Equatable {
    public static let version = "measure-v1"

    public var clusters: [PaletteQuantiser.Cluster]
    /// light, dark, colour, photo.
    public var ground: String
    public var groundHex: String
    /// Left, top, right, bottom, each a share of the side.
    public var margins: [Double]
    /// The share of the piece that is not ground.
    public var ink: Double
    /// Corners holding a small, separate mark: top-left, top-right, bottom-left, bottom-right.
    public var corners: [String]
    /// Lines of text read off the piece (OCR), when it ran.
    public var words: [String]?

    /// Measures `image` (drawn at most 200 px on its long side for the palette and space).
    public static func measure(_ image: CGImage) -> PieceMeasure {
        let (pixels, w, h) = PieceRaster.rgba(image, side: 200)
        let points = PaletteQuantiser.points(rgba: pixels, count: w * h, width: w)
        let clusters = PaletteQuantiser.clusters(points, k: 8, merge: 0.035).filter { $0.share >= 0.002 }
        func lab(_ x: Int, _ y: Int) -> OKLab {
            let o = (y * w + x) * 4
            return OKLab(r: Double(pixels[o]) / 255, g: Double(pixels[o + 1]) / 255, b: Double(pixels[o + 2]) / 255)
        }
        // The ground: the frame's colour, and how much the frame varies.
        let band = max(Int(Double(min(w, h)) * 0.04), 1)
        var frame: [OKLab] = []
        for y in 0..<h { for x in 0..<w where x < band || y < band || x >= w - band || y >= h - band { frame.append(lab(x, y)) } }
        // A designed frame is one or two flat colours (a page, a band); a photograph's is many.
        let framed = PaletteQuantiser.clusters(frame.map { .init(lab: $0, weight: 1) }, k: 4, merge: 0.06)
        let groundLab = framed.first?.lab ?? median(frame)
        let flat = framed.prefix(2).reduce(0) { $0 + $1.share }
        let ground: String
        if flat < 0.85 { ground = "photo" }
        else if groundLab.l > 0.72 && groundLab.chroma < 0.06 { ground = "light" }
        else if groundLab.l < 0.38 { ground = "dark" }
        else if groundLab.chroma >= 0.06 { ground = "colour" }
        else { ground = groundLab.l >= 0.55 ? "light" : "dark" }
        // Ink: what differs from the ground. Margins: the box the ink keeps to, rows and columns with any real ink.
        var mask = [Bool](repeating: false, count: w * h)
        var inked = 0
        for y in 0..<h { for x in 0..<w where lab(x, y).distance(groundLab) > 0.1 { mask[y * w + x] = true; inked += 1 } }
        func row(_ y: Int) -> Int { (0..<w).reduce(0) { $0 + (mask[y * w + $1] ? 1 : 0) } }
        func column(_ x: Int) -> Int { (0..<h).reduce(0) { $0 + (mask[$1 * w + x] ? 1 : 0) } }
        let rows = (0..<h).map(row), columns = (0..<w).map(column)
        let rowFloor = max(Int(Double(w) * 0.004), 1), columnFloor = max(Int(Double(h) * 0.004), 1)
        let top = rows.firstIndex { $0 >= rowFloor } ?? 0
        let bottom = rows.lastIndex { $0 >= rowFloor } ?? (h - 1)
        let left = columns.firstIndex { $0 >= columnFloor } ?? 0
        let right = columns.lastIndex { $0 >= columnFloor } ?? (w - 1)
        let margins = ground == "photo" ? [0, 0, 0, 0]
            : [Double(left) / Double(w), Double(top) / Double(h), Double(w - 1 - right) / Double(w), Double(h - 1 - bottom) / Double(h)]
        // A corner mark: some ink in a corner's square, and a clear band between it and the rest of the piece.
        var corners: [String] = []
        let side = max(Int(Double(min(w, h)) * 0.16), 4), gap = max(side / 4, 2)
        for (name, cx, cy) in [("top-left", 0, 0), ("top-right", w - side, 0), ("bottom-left", 0, h - side), ("bottom-right", w - side, h - side)] {
            var inside = 0, ring = 0, ringCount = 0
            for y in max(cy - gap, 0)..<min(cy + side + gap, h) {
                for x in max(cx - gap, 0)..<min(cx + side + gap, w) {
                    let isInside = x >= cx && x < cx + side && y >= cy && y < cy + side
                    if isInside { inside += mask[y * w + x] ? 1 : 0 } else { ring += mask[y * w + x] ? 1 : 0; ringCount += 1 }
                }
            }
            let share = Double(inside) / Double(side * side)
            if share > 0.03 && share < 0.6 && Double(ring) / Double(max(ringCount, 1)) < 0.02 { corners.append(name) }
        }
        return PieceMeasure(clusters: clusters, ground: ground, groundHex: groundLab.hex, margins: margins,
                            ink: Double(inked) / Double(max(w * h, 1)), corners: corners, words: nil)
    }

    /// The colour in the middle of `colours`, channel by channel.
    static func median(_ colours: [OKLab]) -> OKLab {
        guard !colours.isEmpty else { return OKLab(l: 1, a: 0, b: 0) }
        func mid(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }
        return OKLab(l: mid(colours.map(\.l)), a: mid(colours.map(\.a)), b: mid(colours.map(\.b)))
    }
}
