import Foundation

/// One page of a piece: its blocks in reading order, and, rarely, the engine the model asks for it by name (the kit
/// takes it only when the style draws with that engine).
public struct PiecePage: Codable, Sendable, Equatable {
    public var blocks: [PieceBlock]
    public var archetype: Archetype?

    public init(blocks: [PieceBlock], archetype: Archetype? = nil) { self.blocks = blocks; self.archetype = archetype }

    enum CodingKeys: String, CodingKey { case blocks, archetype }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blocks = PieceLoose.list(c, .blocks, of: PieceBlock.self)
        archetype = try? c.decodeIfPresent(Archetype.self, forKey: .archetype)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(blocks, forKey: .blocks)
        try c.encodeIfPresent(archetype, forKey: .archetype)
    }

    public func first(_ kind: PieceBlock.Kind) -> PieceBlock? { blocks.first { $0.kind == kind } }
    public func count(_ kind: PieceBlock.Kind) -> Int { blocks.filter { $0.kind == kind }.count }
}
