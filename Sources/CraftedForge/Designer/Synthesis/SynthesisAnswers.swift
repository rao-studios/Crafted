//  WHAT: What each of the five synthesis asks answers, and the words ask: only what was marked YOURS. Every field the
//        model may leave out is optional, so a short answer still reads; reconcile fills the rest by trust order.

import Foundation

/// `designer.synth.colour`: which palette letter plays each role, per theme; gradients; how colour is spent.
public struct ColourAnswer: Codable, Sendable, Equatable {
    public struct Pair: Codable, Sendable, Equatable { public var light: String; public var dark: String? }
    public var roles: [String: Pair]
    public var gradients: [DesignerStyle.Gradient]?
    public var usage: [String]?
}

/// `designer.synth.type`: a face per role, from the families offered, and the scale's ratio.
public struct TypeAnswer: Codable, Sendable, Equatable {
    public struct Role: Codable, Sendable, Equatable {
        public var family: String
        public var `class`: String?
        public var weight: Int?
        public var style: String?
        public var textCase: String?
        public var tracking: Double?
        public var leading: Double?

        enum CodingKeys: String, CodingKey { case family, `class`, weight, style, textCase = "case", tracking, leading }
    }
    public var roles: [String: Role]
    public var ratio: Double?
}

/// `designer.synth.layout`: how a page is set, and which engine draws which format.
public struct LayoutAnswer: Codable, Sendable, Equatable {
    public var alignment: String?
    public var symmetry: String?
    public var density: String?
    public var columns: Int?
    public var archetypes: [DesignerStyle.Rule]
}

/// `designer.synth.imagery`: pictures and how they are treated, and motifs written as CSS.
public struct ImageryAnswer: Codable, Sendable, Equatable {
    public var kinds: [String]?
    public var treatments: [String]?
    public var rules: [String]?
    public var placeholder: String?
    public var motifs: [DesignerStyle.Motif]?
}

/// `designer.synth.voice`: how the style speaks.
public struct VoiceAnswer: Codable, Sendable, Equatable {
    public var tone: [String]
    public var headline: String?
    public var vocabulary: [String]?
    public var avoid: [String]?
    /// Lines from the designer's own pieces, chosen verbatim from the words read.
    public var samples: [String]?
}

/// `designer.words`: the style's name, a tagline and keywords for the listing.
public struct WordsAnswer: Codable, Sendable, Equatable {
    public var style: String
    public var tagline: String
    public var keywords: [String]
}
