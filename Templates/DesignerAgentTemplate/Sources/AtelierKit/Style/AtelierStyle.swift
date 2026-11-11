//  WHAT: One designer's style as the kit draws with it: `crafted-style/1`. Its credit, colours (a palette and the
//        roles that read it, in light and dark), type (families and roles), space, shape, layout (which engine for
//        which format), imagery, motifs, mark and voice, and where it came from.
//  IN:   Resources/Style/style.json, written by Crafted from the designer's folder (or the template's own default).
//  OUT:  StyleCSS (the page's variables and faces), ArchetypeChooser, the colophon, the agent's draft prompt.
//  PIN:  ROLES HOLD PALETTE IDS. A hex lives once, in the palette; a role names an id per theme, so a colour changed
//        in the palette changes every role that reads it.
//  PIN:  READ LOOSELY. A key left out takes its default and a list element that does not read is dropped alone: a
//        style is never refused for a field the kit can do without.

import Foundation

public struct AtelierStyle: Codable, Sendable, Equatable {
    public static let format = "crafted-style/1"

    public var format: String
    public var name: String
    public var credit: StyleCredit
    public var colour: StyleColour
    public var type: StyleType
    public var space: StyleSpace
    public var shape: StyleShape
    public var layout: StyleLayout
    public var imagery: StyleImagery
    public var motifs: [StyleMotif]
    public var mark: StyleMark?
    public var voice: StyleVoice
    public var provenance: StyleProvenance?

    public init(name: String, credit: StyleCredit, colour: StyleColour, type: StyleType, space: StyleSpace = StyleSpace(),
                shape: StyleShape = StyleShape(), layout: StyleLayout = StyleLayout(), imagery: StyleImagery = StyleImagery(),
                motifs: [StyleMotif] = [], mark: StyleMark? = nil, voice: StyleVoice = StyleVoice(), provenance: StyleProvenance? = nil) {
        self.format = Self.format; self.name = name; self.credit = credit; self.colour = colour; self.type = type
        self.space = space; self.shape = shape; self.layout = layout; self.imagery = imagery; self.motifs = motifs
        self.mark = mark; self.voice = voice; self.provenance = provenance
    }

    enum CodingKeys: String, CodingKey { case format, name, credit, colour, type, space, shape, layout, imagery, motifs, mark, voice, provenance }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = PieceLoose.string(c, .format) ?? Self.format
        name = PieceLoose.string(c, .name) ?? "Untitled style"
        credit = (try? c.decodeIfPresent(StyleCredit.self, forKey: .credit)) ?? StyleCredit(designer: "the designer")
        colour = try c.decode(StyleColour.self, forKey: .colour)
        type = try c.decode(StyleType.self, forKey: .type)
        space = (try? c.decodeIfPresent(StyleSpace.self, forKey: .space)) ?? StyleSpace()
        shape = (try? c.decodeIfPresent(StyleShape.self, forKey: .shape)) ?? StyleShape()
        layout = (try? c.decodeIfPresent(StyleLayout.self, forKey: .layout)) ?? StyleLayout()
        imagery = (try? c.decodeIfPresent(StyleImagery.self, forKey: .imagery)) ?? StyleImagery()
        motifs = PieceLoose.list(c, .motifs, of: StyleMotif.self)
        mark = try? c.decodeIfPresent(StyleMark.self, forKey: .mark)
        voice = (try? c.decodeIfPresent(StyleVoice.self, forKey: .voice)) ?? StyleVoice()
        provenance = try? c.decodeIfPresent(StyleProvenance.self, forKey: .provenance)
    }

    /// A style from its JSON, or why it does not read.
    public static func read(_ data: Data) throws -> AtelierStyle {
        do {
            return try JSONDecoder().decode(AtelierStyle.self, from: data)
        } catch {
            throw PieceError.style("style.json does not read as \(format): \(PieceLoose.describe(error))")
        }
    }

    /// The colophon's words: "Design by Mira Hale · Swiss Mono", and the designer's own line when they gave one.
    public var colophon: String {
        let base = "Design by \(credit.designer) · \(name)"
        guard let line = credit.line?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else { return base }
        return base + " · " + line
    }
}
