//  WHAT: Which pieces the vision model looks at when there are more than it may: farthest-point selection, so the
//        sample spans the folder (its light and dark pieces, its sparse and busy ones) instead of the first N.
//  PIN:  DETERMINISTIC. It starts from the first piece by path and breaks ties by order, so a resumed run samples the
//        same pieces and finds their looks in the cache.

import Foundation

public enum FarthestPoints {
    /// The indices of up to `count` items, each next the one farthest from those chosen, by `distance`.
    public static func select(_ count: Int, of n: Int, distance: (Int, Int) -> Double) -> [Int] {
        guard n > 0, count > 0 else { return [] }
        guard count < n else { return Array(0..<n) }
        var chosen = [0]
        var nearest = (0..<n).map { distance(0, $0) }
        while chosen.count < count {
            var best = -1
            for i in 0..<n where !chosen.contains(i) && (best < 0 || nearest[i] > nearest[best]) { best = i }
            guard best >= 0 else { break }
            chosen.append(best)
            for i in 0..<n { nearest[i] = min(nearest[i], distance(best, i)) }
        }
        return chosen.sorted()
    }
}
