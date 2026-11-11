import Foundation

/// A layout engine: how a page's blocks are set out. Each is a fixed composition of zones the kit fits type into.
///
/// - `hero`: one large headline owns the page; everything else is quieter, above or below it.
/// - `split`: two panels, a picture (or a colour field) beside the words, or above them on a tall page.
/// - `column`: a head, then one reading column: text that is read, not glanced at.
/// - `grid`: a head, then the blocks as cells of a modular grid: many short things side by side.
public enum Archetype: String, Codable, Sendable, CaseIterable {
    case hero, split, column, grid

    public init(from decoder: Decoder) throws {
        let word = ((try? decoder.singleValueContainer().decode(String.self)) ?? "").lowercased()
        guard let archetype = Archetype(rawValue: word) ?? Archetype.alias[word] else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "\"\(word)\" is not an engine"))
        }
        self = archetype
    }

    static let alias: [String: Archetype] = [
        "cover": .hero, "centre": .hero, "center": .hero, "type": .hero, "band": .hero,
        "halves": .split, "sidebyside": .split, "frame": .split,
        "text": .column, "editorial": .column, "single": .column,
        "modular": .grid, "cards": .grid, "mosaic": .grid,
    ]

    /// The engine that draws it.
    var engine: any LayoutEngine.Type {
        switch self {
        case .hero: return HeroEngine.self
        case .split: return SplitEngine.self
        case .column: return ColumnEngine.self
        case .grid: return GridEngine.self
        }
    }
}
