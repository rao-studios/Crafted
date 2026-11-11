import Foundation

/// A style's space: its unit, the steps of its spacing scale, the page's margin and the gutter between columns (each a
/// share of the page's short side), and how full the designer fills a page.
public struct StyleSpace: Codable, Sendable, Equatable {
    public var unit: Double
    public var scale: [Double]
    public var pageMargin: Double
    public var gutter: Double
    /// sparse, balanced, dense.
    public var density: String

    public init(unit: Double = 8, scale: [Double] = [0.5, 1, 1.5, 2, 3, 4, 6, 8], pageMargin: Double = 0.07,
                gutter: Double = 0.03, density: String = "balanced") {
        self.unit = unit; self.scale = scale; self.pageMargin = pageMargin; self.gutter = gutter; self.density = density
    }

    enum CodingKeys: String, CodingKey { case unit, scale, pageMargin, gutter, density }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unit = min(max(PieceLoose.double(c, .unit) ?? 8, 2), 24)
        scale = PieceLoose.list(c, .scale, of: Double.self)
        if scale.isEmpty { scale = [0.5, 1, 1.5, 2, 3, 4, 6, 8] }
        pageMargin = min(max(PieceLoose.double(c, .pageMargin) ?? 0.07, 0.02), 0.16)
        gutter = min(max(PieceLoose.double(c, .gutter) ?? 0.03, 0.01), 0.08)
        density = PieceLoose.string(c, .density) ?? "balanced"
    }

    /// The gap between blocks, as a share of the type unit: what density means on the page.
    public var flow: Double {
        switch density {
        case "sparse": return 1.5
        case "dense": return 0.7
        default: return 1.0
        }
    }
}
