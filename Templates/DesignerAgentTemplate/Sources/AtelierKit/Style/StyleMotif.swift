import Foundation

/// A motif of the style, expressed as CSS or as a redrawn vector the style ships: what it is, the slot it fills on a
/// page (background, corner, divider, frame, accent), and when to use it.
///
/// PIN: NEVER A PICTURE OF THE DESIGNER'S WORK. A motif is CSS (`MotifCSS` keeps only safe declarations) or an asset
/// under Resources/Style/Motifs that the designer cleared; sample pieces never ship.
public struct StyleMotif: Codable, Sendable, Equatable {
    public var id: String
    /// rule, shape, pattern, texture, line, grain, gradient, frame.
    public var kind: String
    /// background, corner, divider, frame, accent.
    public var slot: String
    public var css: String?
    /// A path under Resources/Style: "Motifs/arc.svg".
    public var asset: String?
    public var use: String?

    public init(id: String, kind: String, slot: String, css: String? = nil, asset: String? = nil, use: String? = nil) {
        self.id = id; self.kind = kind; self.slot = slot; self.css = css; self.asset = asset; self.use = use
    }

    enum CodingKeys: String, CodingKey { case id, kind, slot, css, asset, use }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = PieceLoose.slug(PieceLoose.string(c, .id) ?? "motif")
        kind = PieceLoose.string(c, .kind) ?? "shape"
        slot = PieceLoose.string(c, .slot) ?? "background"
        css = PieceLoose.string(c, .css)?.nonEmptyText
        asset = PieceLoose.string(c, .asset)?.nonEmptyText
        use = PieceLoose.string(c, .use)?.nonEmptyText
    }
}
