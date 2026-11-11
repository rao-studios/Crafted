//  WHAT: Holds a vision answer to what the look asked: every colour a letter of the measured palette (never a hex),
//        every value from its closed list, no typeface named anywhere. Each problem is a sentence the repair ask
//        carries back to the model.
//  PIN:  A HEX IS NEVER ACCEPTED. A model that answers "#E30613" has invented a colour code measures did not give it;
//        the palette's letters are the only colours it may name.

import Foundation

public enum ObservationCheck {
    public static func problems(_ o: Observation, letters: Set<String>) -> [String] {
        typealias V = ObservationVocabulary
        var problems: [String] = []
        func closed(_ value: String, _ list: Set<String>, _ key: String) {
            if value != "unsure" && !list.contains(value) {
                problems.append("\(key) is \"\(value)\", which is not one of: \(list.sorted().joined(separator: ", ")), or unsure.")
            }
        }
        func letter(_ value: String, _ key: String) {
            if Self.hasHex(value) {
                problems.append("\(key) is \"\(value)\": name colours only by the palette's letters (\(letters.sorted().joined(separator: ", "))), never a hex.")
            } else if value != "unsure" && !letters.contains(value) {
                problems.append("\(key) is \"\(value)\", which is not a letter of the palette (\(letters.sorted().joined(separator: ", "))).")
            }
        }
        closed(o.piece.kind, V.pieceKinds, "piece.kind")
        closed(o.piece.confidence, V.confidence, "piece.confidence")
        closed(o.ground, V.grounds, "ground")
        letter(o.colourRoles.background, "colourRoles.background")
        letter(o.colourRoles.ink, "colourRoles.ink")
        for (key, values) in [("accent", o.colourRoles.accent), ("secondary", o.colourRoles.secondary), ("muted", o.colourRoles.muted)] {
            for value in values { letter(value, "colourRoles.\(key)") }
        }
        closed(o.layout.structure, V.structures, "layout.structure")
        closed(o.layout.alignment, V.alignments, "layout.alignment")
        closed(o.layout.margins, V.margins, "layout.margins")
        closed(o.layout.density, V.densities, "layout.density")
        closed(o.layout.symmetry, V.symmetries, "layout.symmetry")
        if o.layout.columns < 0 || o.layout.columns > 12 { problems.append("layout.columns is \(o.layout.columns): 0 (unsure) to 12.") }
        closed(o.hierarchy.headline.position, V.positions, "hierarchy.headline.position")
        closed(o.hierarchy.headline.scale, V.scales, "hierarchy.headline.scale")
        closed(o.hierarchy.headline.case, V.cases, "hierarchy.headline.case")
        closed(o.hierarchy.headline.treatment, V.treatments, "hierarchy.headline.treatment")
        closed(o.hierarchy.emphasis, V.emphases, "hierarchy.emphasis")
        for (i, use) in o.type.enumerated() {
            closed(use.role, V.typeRoles, "type[\(i)].role")
            closed(use.class, V.typeClasses, "type[\(i)].class")
            closed(use.sub, V.typeSubs, "type[\(i)].sub")
            closed(use.weight, V.weights, "type[\(i)].weight")
            closed(use.width, V.widths, "type[\(i)].width")
            closed(use.slant, V.slants, "type[\(i)].slant")
            closed(use.tracking, V.trackings, "type[\(i)].tracking")
            closed(use.contrast, V.contrasts, "type[\(i)].contrast")
        }
        for kind in o.imagery.kinds { closed(kind, V.imageryKinds, "imagery.kinds") }
        closed(o.imagery.treatment, V.imageryTreatments, "imagery.treatment")
        closed(o.imagery.share, V.shares, "imagery.share")
        for (i, motif) in o.motifs.enumerated() {
            closed(motif.kind, V.motifKinds, "motifs[\(i)].kind")
            closed(motif.where, V.motifPlaces, "motifs[\(i)].where")
        }
        closed(o.shape.corners, V.corners, "shape.corners")
        closed(o.shape.strokes, V.strokes, "shape.strokes")
        closed(o.shape.shadows, V.shadows, "shape.shadows")
        closed(o.shape.fills, V.fills, "shape.fills")
        for mood in o.mood { closed(mood, V.moods, "mood") }
        for (i, mark) in o.marks.enumerated() {
            closed(mark.what, V.markKinds, "marks[\(i)].what")
            closed(mark.where, V.markPlaces, "marks[\(i)].where")
        }
        closed(o.people, V.people, "people")
        // Free words: a motif's name and the notes. No hex and no typeface in either.
        let free = o.motifs.map(\.name) + [o.notes ?? ""]
        for text in free {
            if hasHex(text) { problems.append("\"\(text.prefix(60))\" carries a hex: name colours by the palette's letters only.") }
            if let face = typeface(in: text) { problems.append("\"\(text.prefix(60))\" names a typeface (\(face)): describe type by its class, never its name.") }
        }
        return problems
    }

    /// A hex colour anywhere in `text`: "#E30613", "#fff", "E30613".
    public static func hasHex(_ text: String) -> Bool {
        // No letter or listed word holds a "#"; a bare six-digit hex holds at least one digit ("E30613", not "facade").
        text.contains("#") || text.range(of: #"\b(?=[0-9A-Fa-f]*[0-9])[0-9A-Fa-f]{6}\b"#, options: .regularExpression) != nil
    }

    /// The first typeface named in `text`, if any.
    static func typeface(in text: String) -> String? {
        let lower = " " + text.lowercased() + " "
        return ObservationVocabulary.typefaces.first { name in
            lower.range(of: "[^a-z]" + NSRegularExpression.escapedPattern(for: name) + "[^a-z]", options: .regularExpression) != nil
        }
    }
}
