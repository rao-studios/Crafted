//  WHAT: A palette from pixels: weighted k-means in OKLab, area weights, near colours merged. Pixels are first
//        binned (5 bits a channel) so a whole picture is a few hundred weighted points, not a million.
//  IN:   A piece's pixels (PieceMeasurer), or every piece's clusters (DesignMeasures, the folder's palette).
//  OUT:  Clusters with their share of the area, largest first.
//  PIN:  DETERMINISTIC. Seeds are farthest-first from the heaviest point, never random, so the same folder gives the
//        same palette and the same letters every time; a scripted look keyed on those letters keeps working.

import Foundation

public enum PaletteQuantiser {
    public struct Point: Sendable, Equatable {
        public var lab: OKLab
        public var weight: Double
        public init(lab: OKLab, weight: Double) { self.lab = lab; self.weight = weight }
    }

    public struct Cluster: Codable, Sendable, Equatable {
        public var lab: OKLab
        public var hex: String
        /// Its share of the weight, 0 to 1.
        public var share: Double
        public init(lab: OKLab, share: Double) { self.lab = lab; self.hex = lab.hex; self.share = share }
    }

    /// RGBA pixels (8 bits a channel, premultiplied or not; alpha under half is skipped), binned to points. With a
    /// `width`, a pixel on an edge (one that differs sharply from its right or lower neighbour) is skipped: an
    /// anti-aliased glyph's rim is a blend of two colours, never a colour of the design.
    public static func points(rgba: [UInt8], count: Int, width: Int? = nil) -> [Point] {
        var bins: [UInt16: (Double, Double, Double, Double)] = [:]
        func edge(_ i: Int, _ w: Int) -> Bool {
            let o = i * 4
            for n in [i + 1, i + w] where n < count && (n != i + 1 || (i + 1) % w != 0) {
                let p = n * 4
                if max(abs(Int(rgba[o]) - Int(rgba[p])), abs(Int(rgba[o + 1]) - Int(rgba[p + 1])), abs(Int(rgba[o + 2]) - Int(rgba[p + 2]))) > 40 { return true }
            }
            return false
        }
        for i in 0..<count {
            let o = i * 4
            guard rgba[o + 3] >= 128 else { continue }
            if let width, edge(i, width) { continue }
            let (r, g, b) = (rgba[o], rgba[o + 1], rgba[o + 2])
            let key = UInt16(r >> 3) << 10 | UInt16(g >> 3) << 5 | UInt16(b >> 3)
            let sum = bins[key] ?? (0, 0, 0, 0)
            bins[key] = (sum.0 + Double(r), sum.1 + Double(g), sum.2 + Double(b), sum.3 + 1)
        }
        return bins.keys.sorted().map { key in
            let (r, g, b, n) = bins[key]!
            return Point(lab: OKLab(r: r / n / 255, g: g / n / 255, b: b / n / 255), weight: n)
        }
    }

    /// Up to `k` clusters of `points`, merged where closer than `merge`, largest first.
    public static func clusters(_ points: [Point], k: Int, merge: Double = 0.04, iterations: Int = 24) -> [Cluster] {
        let total = points.reduce(0) { $0 + $1.weight }
        guard total > 0, k > 0 else { return [] }
        var centres = seeds(points, k: min(k, points.count))
        for _ in 0..<iterations {
            var sums = [(Double, Double, Double, Double)](repeating: (0, 0, 0, 0), count: centres.count)
            for point in points {
                let index = nearest(point.lab, centres)
                let w = point.weight
                sums[index] = (sums[index].0 + point.lab.l * w, sums[index].1 + point.lab.a * w, sums[index].2 + point.lab.b * w, sums[index].3 + w)
            }
            var moved = 0.0
            for index in centres.indices where sums[index].3 > 0 {
                let next = OKLab(l: sums[index].0 / sums[index].3, a: sums[index].1 / sums[index].3, b: sums[index].2 / sums[index].3)
                moved = max(moved, next.distance(centres[index]))
                centres[index] = next
            }
            if moved < 1e-5 { break }
        }
        var weights = [Double](repeating: 0, count: centres.count)
        for point in points { weights[nearest(point.lab, centres)] += point.weight }
        var found = zip(centres, weights).filter { $0.1 > 0 }.map { (lab: $0.0, weight: $0.1) }
        // Merge near colours into the heavier one, weighted.
        found.sort { $0.weight > $1.weight }
        var merged: [(lab: OKLab, weight: Double)] = []
        for item in found {
            if let index = merged.firstIndex(where: { $0.lab.distance(item.lab) < merge }) {
                let w = merged[index].weight + item.weight
                let a = merged[index]
                merged[index] = (OKLab(l: (a.lab.l * a.weight + item.lab.l * item.weight) / w, a: (a.lab.a * a.weight + item.lab.a * item.weight) / w,
                                       b: (a.lab.b * a.weight + item.lab.b * item.weight) / w), w)
            } else {
                merged.append(item)
            }
        }
        return merged.sorted { $0.weight > $1.weight }.map { Cluster(lab: $0.lab, share: $0.weight / total) }
    }

    /// Farthest-first seeds from the heaviest point: each next seed the point farthest from every seed so far,
    /// weighted a little by how much of the picture it is.
    static func seeds(_ points: [Point], k: Int) -> [OKLab] {
        guard let heaviest = points.max(by: { $0.weight < $1.weight || ($0.weight == $1.weight && $0.lab.l > $1.lab.l) }) else { return [] }
        var seeds = [heaviest.lab]
        let total = points.reduce(0) { $0 + $1.weight }
        while seeds.count < k {
            var best: (score: Double, lab: OKLab)?
            for point in points {
                let d = seeds.map { $0.distance(point.lab) }.min() ?? 0
                let score = d * (0.6 + 0.4 * (point.weight / total).squareRoot())
                if best == nil || score > best!.score { best = (score, point.lab) }
            }
            guard let best, best.score > 1e-4 else { break }
            seeds.append(best.lab)
        }
        return seeds
    }

    static func nearest(_ lab: OKLab, _ centres: [OKLab]) -> Int {
        var index = 0
        var best = Double.infinity
        for (i, centre) in centres.enumerated() {
            let d = lab.distance(centre)
            if d < best { best = d; index = i }
        }
        return index
    }
}
