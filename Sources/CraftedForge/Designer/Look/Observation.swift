//  WHAT: What the vision model saw in one piece: what kind of piece it is, its ground, which of the measured palette's
//        letters play which part, its layout, hierarchy and type (classified, never named), its imagery, motifs,
//        shapes and mood, the marks on it (the designer's, a client's, a stock watermark), and whether people appear.
//  IN:   One `designer.look` ask per piece.
//  OUT:  artefacts/looks/<piece>.json (and the shared cache's looks); reconcile and synthesis read the consensus.
//  PIN:  EVERY VALUE FROM A CLOSED LIST, "unsure" allowed (ObservationVocabulary). Colours are palette letters only;
//        a typeface is a class, never a name. `ObservationCheck` refuses an answer that breaks either.

import Foundation

public struct Observation: Codable, Sendable, Equatable {
    public struct Piece: Codable, Sendable, Equatable { public var kind: String; public var confidence: String }

    public struct ColourRoles: Codable, Sendable, Equatable {
        public var background: String
        public var ink: String
        public var accent: [String]
        public var secondary: [String]
        public var muted: [String]
    }

    public struct Layout: Codable, Sendable, Equatable {
        public var structure: String
        public var columns: Int
        public var alignment: String
        public var margins: String
        public var density: String
        public var symmetry: String
    }

    public struct Headline: Codable, Sendable, Equatable {
        public var position: String
        public var scale: String
        public var `case`: String
        public var treatment: String
    }

    public struct Hierarchy: Codable, Sendable, Equatable {
        public var levels: Int
        public var headline: Headline
        public var emphasis: String
    }

    public struct TypeUse: Codable, Sendable, Equatable {
        public var role: String
        public var `class`: String
        public var sub: String
        public var weight: String
        public var width: String
        public var slant: String
        public var tracking: String
        public var contrast: String
    }

    public struct Imagery: Codable, Sendable, Equatable {
        public var kinds: [String]
        public var treatment: String
        public var share: String
    }

    public struct Motif: Codable, Sendable, Equatable {
        public var name: String
        public var kind: String
        public var `where`: String
    }

    public struct Shape: Codable, Sendable, Equatable {
        public var corners: String
        public var strokes: String
        public var shadows: String
        public var fills: String
    }

    public struct Mark: Codable, Sendable, Equatable {
        public var what: String
        public var `where`: String
        public var text: String?
    }

    public var piece: Piece
    public var ground: String
    public var colourRoles: ColourRoles
    public var layout: Layout
    public var hierarchy: Hierarchy
    public var type: [TypeUse]
    public var imagery: Imagery
    public var motifs: [Motif]
    public var shape: Shape
    public var mood: [String]
    public var marks: [Mark]
    public var people: String
    public var notes: String?
}
