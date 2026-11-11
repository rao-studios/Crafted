import Foundation

/// A style's shapes: the corner radius and stroke of its boxes (CSS pixels on a letter page), its shadows and its fills.
public struct StyleShape: Codable, Sendable, Equatable {
    public var radius: Double
    public var stroke: Double
    /// none, soft, hard.
    public var shadow: String
    /// flat, gradient, textured.
    public var fills: String

    public init(radius: Double = 0, stroke: Double = 1, shadow: String = "none", fills: String = "flat") {
        self.radius = radius; self.stroke = stroke; self.shadow = shadow; self.fills = fills
    }

    enum CodingKeys: String, CodingKey { case radius, stroke, shadow, fills }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        radius = min(max(PieceLoose.double(c, .radius) ?? 0, 0), 64)
        stroke = min(max(PieceLoose.double(c, .stroke) ?? 1, 0), 8)
        shadow = PieceLoose.string(c, .shadow) ?? "none"
        fills = PieceLoose.string(c, .fills) ?? "flat"
    }

    /// The CSS box-shadow the style's shadow word means.
    public var boxShadow: String {
        switch shadow {
        case "soft": return "0 10px 30px rgba(0,0,0,.12)"
        case "hard": return "6px 6px 0 var(--ink)"
        default: return "none"
        }
    }
}
