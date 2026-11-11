//  WHAT: The user side of each synthesis ask: LOCKED, what code measured, the designer declared and the looks agree on
//        (the model keeps to it); YOURS, what the model decides. Built from the run's artefacts only, so the same run
//        asks the same thing and finds its answer in the ledger.

import Foundation

public struct SynthesisBrief: Sendable {
    public let measures: DesignMeasures
    public let consensus: LookConsensus
    public let rights: RightsOutcome
    public let fallbacks: FallbackFaces

    public init(measures: DesignMeasures, consensus: LookConsensus, rights: RightsOutcome, fallbacks: FallbackFaces) {
        self.measures = measures; self.consensus = consensus; self.rights = rights; self.fallbacks = fallbacks
    }

    var hasDark: Bool { (measures.grounds["dark"] ?? 0) > 0 }
    var letters: Set<String> { Set(measures.palette.map(\.id)) }

    public var colour: String {
        var locked = ["The palette, by letter:"] + measures.paletteLines.map { "- " + $0 }
        for (role, themes) in measures.roles.sorted(by: { $0.key < $1.key }) {
            for (theme, letter) in themes.sorted(by: { $0.key < $1.key }) { locked.append("Measured: \(role) in the \(theme) theme is \(letter).") }
        }
        for colour in measures.declared.colours where colour.role != nil {
            if let letter = measures.palette.first(where: { $0.hex == colour.hex })?.id {
                locked.append("Declared: \(colour.role!) is \(letter) (\(colour.name) in \(colour.source)).")
            }
        }
        for role in ["background", "ink", "accent", "secondary", "inkMuted"] {
            for theme in ["light", "dark"] {
                if let letter = consensus.colour(role, theme: theme) { locked.append("Seen: most \(theme) pieces use \(letter) as \(role).") }
            }
        }
        locked.append("Grounds of the pieces: " + measures.grounds.sorted { $0.key < $1.key }.map { "\($0.value) \($0.key)" }.joined(separator: ", ") + ".")
        var yours = ["A letter for every role in both themes: \(DesignerStyle.colourRoles.joined(separator: ", ")). Keep every LOCKED role as it is."]
        if !hasDark { yours.append("The designer's pieces are all light: choose the dark theme's letters so its ink reads on its background.") }
        if (measures.grounds["light"] ?? 0) + (measures.grounds["colour"] ?? 0) == 0 {
            yours.append("The designer's pieces are all dark: choose the light theme's letters so its ink reads on its background.")
        }
        yours.append("Up to two gradients, only if the pieces show one; one or two sentences of usage.")
        return section(locked, yours)
    }

    /// The families a type role may take: those that ship, declared system faces, and stand-ins for the classes seen.
    public var available: [String] {
        var names = rights.cleared.map(\.family)
        let system = Set(fallbacks.all.map { $0.lowercased() })
        names += measures.declared.faces.map(\.family).filter { system.contains($0.lowercased()) }
        for role in DesignerStyle.typeRoles {
            names += fallbacks.faces(class: consensus.typeClass(role), sub: consensus.typeValue(role) { $0.sub }).prefix(2)
        }
        var seen: Set<String> = []
        return names.filter { seen.insert($0.lowercased()).inserted }
    }

    public var type: String {
        var locked: [String] = []
        for font in rights.fonts {
            let fact = measures.fonts.first { $0.family == font.family }
            locked.append("In the folder: \(font.family) (\(fact?.class ?? "unsure")\(fact?.italic == true ? ", italic" : "")): "
                          + (font.decision == "substitute" ? "it does not ship; a stand-in of its class draws it." : "it ships."))
        }
        for face in measures.declared.faces {
            let missing = !available.contains { $0.lowercased() == face.family.lowercased() }
            locked.append("Declared: \(face.role ?? "a face") is \"\(face.family)\" (\(face.name) in \(face.source))"
                          + (missing ? ": it is not in the folder and cannot ship, so a stand-in of its class draws it." : "."))
        }
        for role in DesignerStyle.typeRoles {
            guard let cls = consensus.typeClass(role) else { continue }
            let parts = [cls, consensus.typeValue(role) { $0.sub }, consensus.typeValue(role) { $0.weight },
                         consensus.typeValue(role) { $0.slant }, consensus.typeValue(role) { $0.tracking }].compactMap { $0 }.filter { $0 != "none" }
            locked.append("Seen: the \(role) is \(parts.joined(separator: ", ")).")
        }
        if let headlineCase = consensus.vote({ $0.hierarchy.headline.case }) { locked.append("Seen: headlines are set in \(headlineCase) case.") }
        locked.append("AVAILABLE families: " + available.map { "\"\($0)\"" }.joined(separator: ", ") + ".")
        let yours = ["A face for every role (\(DesignerStyle.typeRoles.joined(separator: ", "))), each family from AVAILABLE, keeping to what was declared and seen; the scale's ratio."]
        return section(locked, yours)
    }

    public var layout: String {
        let m = measures.margins.map { "\(Int(($0 * 100).rounded()))%" }
        var locked = ["Measured margins: left \(m[0]), top \(m[1]), right \(m[2]), bottom \(m[3]); ink covers \(Int((measures.ink * 100).rounded()))% of a piece."]
        var structures: [String: Int] = [:]
        for look in consensus.looks where look.layout.structure != "unsure" { structures[look.layout.structure, default: 0] += 1 }
        if !structures.isEmpty { locked.append("Seen structures: " + structures.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ") + ".") }
        for (name, value) in [("alignment", consensus.vote { $0.layout.alignment }), ("symmetry", consensus.vote { $0.layout.symmetry }),
                              ("density", consensus.vote { $0.layout.density }), ("headline position", consensus.vote { $0.hierarchy.headline.position })] {
            if let value { locked.append("Seen: \(name) is mostly \(value).") }
        }
        let yours = ["Alignment, symmetry, density and grid columns, keeping to what was seen; engines for every format: \(DesignerStyle.formats.joined(separator: ", ")). Engines: \(DesignerStyle.engines.joined(separator: ", "))."]
        return section(locked, yours)
    }

    public var imagery: String {
        var locked: [String] = []
        let kinds = Set(consensus.looks.flatMap(\.imagery.kinds)).subtracting(["unsure"]).sorted()
        if !kinds.isEmpty { locked.append("Seen imagery: \(kinds.joined(separator: ", ")).") }
        if let treatment = consensus.vote({ $0.imagery.treatment }) { locked.append("Seen treatment: \(treatment).") }
        for motif in consensus.looks.flatMap(\.motifs) { locked.append("Seen motif: \(motif.name) (\(motif.kind), \(motif.where)).") }
        for (name, value) in [("corners", consensus.vote { $0.shape.corners }), ("strokes", consensus.vote { $0.shape.strokes }),
                              ("shadows", consensus.vote { $0.shape.shadows }), ("fills", consensus.vote { $0.shape.fills })] {
            if let value { locked.append("Seen: \(name) are \(value).") }
        }
        if locked.isEmpty { locked.append("Nothing was seen of imagery or motifs.") }
        let yours = ["Imagery kinds and treatments, rules for pictures, the placeholder treatment, and up to three motifs as CSS that redraw what was seen. Never a picture of the designer's."]
        return section(locked, yours)
    }

    public var voice: String {
        var locked: [String] = []
        if measures.words.isEmpty { locked.append("WORDS READ: none.") } else {
            locked.append("WORDS READ off the pieces:")
            locked += measures.words.prefix(40).map { "- " + $0 }
        }
        var moods: [String: Int] = [:]
        for mood in consensus.looks.flatMap(\.mood) where mood != "unsure" { moods[mood, default: 0] += 1 }
        if !moods.isEmpty { locked.append("Seen moods: " + moods.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(5).map(\.key).joined(separator: ", ") + ".") }
        let yours = ["Tone, how a headline reads, vocabulary, words to avoid, and up to five samples copied exactly from WORDS READ."]
        return section(locked, yours)
    }

    func section(_ locked: [String], _ yours: [String]) -> String {
        "LOCKED\n" + locked.joined(separator: "\n") + "\n\nYOURS\n" + yours.joined(separator: "\n")
    }
}
