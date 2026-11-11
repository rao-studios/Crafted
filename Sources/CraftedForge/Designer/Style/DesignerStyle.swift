//  WHAT: A designer's style as the forge writes it: `crafted-style/1`, the file the template's kit draws with
//        (Templates/DesignerAgentTemplate/Sources/AtelierKit/Style, AtelierStyle reads it).
//  OUT:  artefacts/style/style.json → the package's Sources/<Kit>/Resources/Style/style.json.
//  PIN:  ONE SHAPE, TWO READERS. The kit's AtelierStyle and this type read and write the same keys; the forge's
//        tests decode the template's own style fixtures with this type, and the proof draws every format from the
//        file this type wrote, so a key that drifts fails a gate, not a person.
//  PIN:  ROLES HOLD PALETTE IDS. A hex lives once, in the palette.

import Foundation

public struct DesignerStyle: Codable, Sendable, Equatable {
    public static let formatID = "crafted-style/1"

    public struct Credit: Codable, Sendable, Equatable {
        public var designer: String
        public var url: String?
        public var line: String?
        /// default-on, required, off.
        public var colophon: String
        public var styleLicence: String
    }

    public struct Entry: Codable, Sendable, Equatable {
        public var id: String
        public var hex: String
        public var name: String?
        public var weight: Double?
        public var pieces: Int?
        public var source: String?
    }

    public struct Pair: Codable, Sendable, Equatable {
        public var light: String
        public var dark: String?
    }

    public struct Gradient: Codable, Sendable, Equatable {
        public var id: String
        public var stops: [String]
        public var angle: Double?
    }

    public struct Colour: Codable, Sendable, Equatable {
        public var grounds: [String]
        public var palette: [Entry]
        public var roles: [String: Pair]
        public var gradients: [Gradient]
        public var proportions: [String: Double]
        public var usage: [String]

        public func entry(_ id: String) -> Entry? { palette.first { $0.id == id } }
        public func hex(_ role: String, _ theme: String) -> String? {
            guard let pair = roles[role] else { return nil }
            return entry(theme == "dark" ? (pair.dark ?? pair.light) : pair.light)?.hex
        }
    }

    public struct Family: Codable, Sendable, Equatable {
        public var family: String
        public var licence: String?
        public var bundled: Bool
        public var files: [String]
    }

    public struct Role: Codable, Sendable, Equatable {
        public var family: String
        public var source: String?
        public var fallbacks: [String]
        public var `class`: String?
        public var weight: Int
        public var style: String
        public var textCase: String
        public var tracking: Double
        public var leading: Double

        enum CodingKeys: String, CodingKey { case family, source, fallbacks, `class`, weight, style, textCase = "case", tracking, leading }
    }

    public struct Scale: Codable, Sendable, Equatable {
        public var base: Double
        public var ratio: Double
    }

    public struct TypeSystem: Codable, Sendable, Equatable {
        public var families: [Family]
        public var roles: [String: Role]
        public var scale: Scale
    }

    public struct Space: Codable, Sendable, Equatable {
        public var unit: Double
        public var scale: [Double]
        public var pageMargin: Double
        public var gutter: Double
        public var density: String
    }

    public struct Shape: Codable, Sendable, Equatable {
        public var radius: Double
        public var stroke: Double
        public var shadow: String
        public var fills: String
    }

    public struct Rule: Codable, Sendable, Equatable {
        public var engine: String
        public var `for`: [String]
        public var weight: Double
        public var headline: String?
        public var image: String?
    }

    public struct Grid: Codable, Sendable, Equatable {
        public var columns: Int
    }

    public struct Layout: Codable, Sendable, Equatable {
        public var alignment: String
        public var symmetry: String
        public var grid: Grid
        public var archetypes: [Rule]
    }

    public struct Imagery: Codable, Sendable, Equatable {
        public var kinds: [String]
        public var treatments: [String]
        public var rules: [String]
        public var placeholder: String
    }

    public struct Motif: Codable, Sendable, Equatable {
        public var id: String
        public var kind: String
        public var slot: String
        public var css: String?
        public var asset: String?
        public var use: String?
    }

    public struct Mark: Codable, Sendable, Equatable {
        public var asset: String
        public var placement: String
    }

    public struct Voice: Codable, Sendable, Equatable {
        public var tone: [String]
        public var headline: String?
        public var vocabulary: [String]
        public var avoid: [String]
        public var samples: [String]
    }

    public struct Provenance: Codable, Sendable, Equatable {
        public var pieces: Int
        public var looked: Int
        public var models: [String]
        public var decisions: [String]
    }

    public var format: String
    public var name: String
    public var credit: Credit
    public var colour: Colour
    public var type: TypeSystem
    public var space: Space
    public var shape: Shape
    public var layout: Layout
    public var imagery: Imagery
    public var motifs: [Motif]
    public var mark: Mark?
    public var voice: Voice
    public var provenance: Provenance

    /// The colour roles every theme must name.
    public static let colourRoles = ["background", "surface", "ink", "inkMuted", "accent", "accentInk", "secondary", "rule"]
    public static let typeRoles = ["display", "heading", "body", "caption", "label", "numeral"]
    /// The formats and engines the template draws.
    public static let formats = ["poster", "flyer", "brochure", "onepager", "socialcard", "story", "businesscard", "slide", "banner"]
    public static let engines = ["hero", "split", "column", "grid"]
}
