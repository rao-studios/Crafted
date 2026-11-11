import Foundation

/// The designer's own mark, when they confirmed one: a file under Resources/Style ("Marks/mark.svg") and the corner
/// a piece carries it in. A `logo` block draws it too.
public struct StyleMark: Codable, Sendable, Equatable {
    public var asset: String
    /// top-left, top-right, bottom-left, bottom-right, none.
    public var placement: String

    public init(asset: String, placement: String = "top-right") { self.asset = asset; self.placement = placement }

    enum CodingKeys: String, CodingKey { case asset, placement }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        asset = try c.decode(String.self, forKey: .asset)
        placement = PieceLoose.string(c, .placement) ?? "top-right"
    }
}
