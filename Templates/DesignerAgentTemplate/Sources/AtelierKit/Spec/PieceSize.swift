import Foundation

/// A page's size in CSS pixels. `size` in a call: "1200x1600", or a paper ("a4", "a5", "letter", "square", "16:9").
public struct PieceSize: Codable, Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) { self.width = width; self.height = height }

    /// A size a call named, or nil when it names none the kit knows.
    public init?(loose text: String) {
        let word = text.lowercased().replacingOccurrences(of: " ", with: "")
        let papers: [String: (Double, Double)] = [
            "a3": (1123, 1587), "a4": (794, 1123), "a5": (559, 794), "a6": (397, 559), "letter": (850, 1100),
            "tabloid": (1100, 1700), "square": (1080, 1080), "16:9": (1920, 1080), "9:16": (1080, 1920),
            "4:5": (1080, 1350), "3:2": (1500, 1000), "2:3": (1000, 1500),
        ]
        if let (w, h) = papers[word] { self.init(width: w, height: h); return }
        let parts = word.split { $0 == "x" || $0 == "×" || $0 == "*" }.compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        self.init(width: parts[0], height: parts[1])
    }

    /// Kept between 300 and 4000 CSS pixels a side, whole: the PNG is twice it.
    public var clamped: PieceSize {
        PieceSize(width: min(max(width, 300), 4000).rounded(), height: min(max(height, 300), 4000).rounded())
    }

    public var shortSide: Double { min(width, height) }
    public var label: String { "\(Int(width))×\(Int(height))" }
}
