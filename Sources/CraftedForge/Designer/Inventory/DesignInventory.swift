//  WHAT: What a designer's folder holds, as the forge read it: every file with a verdict (a piece, a font, declared
//        tokens, words, a mark, withheld, cannot be opened, skipped), the distinct pieces rasterised for measuring and
//        looking, the near-duplicates collapsed, and the sample the vision model looks at.
//  OUT:  artefacts/inventory.json; every later stage.

import Foundation

public struct DesignInventory: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var path: String
        public var kind: DesignKind
        public var bytes: Int
        /// piece, pages N, font, declared, words, mark, withheld: …, cannot open: export as PDF or PNG, skipped.
        public var verdict: String
    }

    /// One piece: a picture, a PDF's page or an SVG, rasterised under the run's artefacts.
    public struct Piece: Codable, Sendable, Equatable {
        public var id: String
        public var path: String
        /// A PDF's page, from 1.
        public var page: Int?
        /// The PNG the forge measures and shows the vision model, relative to the run's artefacts.
        public var raster: String
        public var sha256: String
        public var width: Int
        public var height: Int
        public var hash: UInt64
        /// Its mean colour, for spreading the sample.
        public var mean: OKLab
        /// The piece this one repeats, when it is a near-duplicate.
        public var duplicateOf: String?

        /// How the piece is named to a person and a model: "poster.png", "menu.pdf, page 2".
        public var label: String { page.map { "\(path), page \($0)" } ?? path }
    }

    public var entries: [Entry]
    public var pieces: [Piece]
    /// The pieces the vision model looks at, by id.
    public var sampled: [String]
    public var fonts: [String]
    /// CSS, tokens and SVG files whose colours and faces are declared.
    public var declared: [String]
    public var texts: [String]
    /// Files named as marks: logos, monograms, signatures.
    public var marks: [String]
    public var unopenable: [String]

    public var distinct: [Piece] { pieces.filter { $0.duplicateOf == nil } }
    public var sample: [Piece] { pieces.filter { sampled.contains($0.id) } }
}
