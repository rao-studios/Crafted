import Foundation

/// A style's layout: how it aligns and balances a page, its grid, and which layout engines it draws each format with.
public struct StyleLayout: Codable, Sendable, Equatable {
    /// An engine the style uses, for which formats (all, when empty), how much it prefers it, where the headline sits
    /// and where a picture goes.
    public struct Rule: Codable, Sendable, Equatable {
        public var engine: Archetype
        public var `for`: [String]
        public var weight: Double
        /// top, middle, bottom.
        public var headline: String?
        /// left, right, top, bottom, background, none.
        public var image: String?

        public init(engine: Archetype, for formats: [String] = [], weight: Double = 1, headline: String? = nil, image: String? = nil) {
            self.engine = engine; self.for = formats; self.weight = weight; self.headline = headline; self.image = image
        }

        enum CodingKeys: String, CodingKey { case engine, `for`, weight, headline, image }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            engine = try c.decode(Archetype.self, forKey: .engine)
            `for` = PieceLoose.list(c, .for, of: String.self)
            weight = min(max(PieceLoose.double(c, .weight) ?? 1, 0), 10)
            headline = PieceLoose.string(c, .headline)
            image = PieceLoose.string(c, .image)
        }

        public func covers(_ format: PieceFormat) -> Bool { self.for.isEmpty || self.for.contains(format.rawValue) }
    }

    public struct Grid: Codable, Sendable, Equatable {
        public var columns: Int

        public init(columns: Int = 2) { self.columns = columns }

        enum CodingKeys: String, CodingKey { case columns }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            columns = min(max(PieceLoose.int(c, .columns) ?? 2, 1), 4)
        }
    }

    /// left, centre, right.
    public var alignment: String
    /// symmetric, asymmetric.
    public var symmetry: String
    public var grid: Grid
    public var archetypes: [Rule]

    public init(alignment: String = "left", symmetry: String = "asymmetric", grid: Grid = Grid(), archetypes: [Rule] = []) {
        self.alignment = alignment; self.symmetry = symmetry; self.grid = grid; self.archetypes = archetypes
    }

    enum CodingKeys: String, CodingKey { case alignment, symmetry, grid, archetypes }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alignment = PieceLoose.string(c, .alignment) ?? "left"
        symmetry = PieceLoose.string(c, .symmetry) ?? "asymmetric"
        grid = (try? c.decodeIfPresent(Grid.self, forKey: .grid)) ?? Grid()
        archetypes = PieceLoose.list(c, .archetypes, of: Rule.self)
    }

    /// The rules that cover `format`.
    public func rules(for format: PieceFormat) -> [Rule] { archetypes.filter { $0.covers(format) && $0.weight > 0 } }

    /// The CSS text-align the alignment word means.
    public var textAlign: String {
        switch alignment {
        case "centre", "center": return "center"
        case "right": return "right"
        default: return "left"
        }
    }
}
