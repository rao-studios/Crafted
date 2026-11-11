//  WHAT: What code measured of the whole folder: one palette (every piece's colours clustered again, weighted by area,
//        declared hexes taken exactly), each colour lettered A, B, C … by weight; the grounds; the margins and ink the
//        pieces keep to; the faces in the folder; what the designer declared; the words read; and the roles code can
//        measure on its own (the ground each theme stands on, and the ink that reads on it).
//  OUT:  artefacts/measures.json; the look prompt (the letters), synthesis (LOCKED facts), reconcile (measured roles).
//  PIN:  LETTERS ARE THE PALETTE'S NAMES. The vision model names colours only by these letters, so what it says of a
//        piece can be checked against what code measured, and never carries a hex of its own.

import CraftedCore
import Foundation

public struct DesignMeasures: Codable, Sendable, Equatable {
    public struct Colour: Codable, Sendable, Equatable {
        public var id: String
        public var hex: String
        public var lab: OKLab
        public var name: String
        /// Its share of the pieces' area, 0 to 1 (0 for a colour only declared).
        public var weight: Double
        /// How many pieces show it.
        public var pieces: Int
        /// measured, declared, measured+declared, adjusted, derived.
        public var source: String
        /// The names the designer declared it under.
        public var declaredAs: [String]
    }

    public struct Credit: Codable, Sendable, Equatable {
        public var name: String
        public var url: String?
        public var source: String
    }

    public var palette: [Colour]
    public var grounds: [String: Int]
    public var pieces: [String: PieceMeasure]
    /// Left, top, right, bottom: the median of the pieces'.
    public var margins: [Double]
    public var ink: Double
    public var fonts: [FontFact]
    public var declared: DeclaredStyle
    /// Lines read off the pieces, each once.
    public var words: [String]
    public var credit: Credit?
    /// Roles code measured, as palette letters per theme ("background" → light "A", dark "F").
    public var roles: [String: [String: String]]

    public func colour(_ id: String) -> Colour? { palette.first { $0.id == id } }

    /// The palette as the look prompt shows it: "A #F7F7F2 white, 61% of the area".
    public var paletteLines: [String] {
        palette.map { "\($0.id) \($0.hex) \($0.name)" + ($0.weight > 0 ? ", \(Int(($0.weight * 100).rounded()))% of the area" : ", declared") }
    }

    /// A short hash of the letters and their colours: a look keyed on it is redone when the palette changes.
    public var paletteKey: String { String(ContentHash.sha256(palette.map { "\($0.id)\($0.hex)" }.joined()).prefix(12)) }

    static let letters = (65...90).map { String(UnicodeScalar($0)!) }

    public static func build(pieces: [DesignInventory.Piece], measures: [String: PieceMeasure], fonts: [FontFact],
                             declared: DeclaredStyle, texts: [String: String]) -> DesignMeasures {
        let distinct = pieces.filter { $0.duplicateOf == nil && measures[$0.id] != nil }
        let n = Double(max(distinct.count, 1))
        // Every piece's clusters as points weighted by their share of that piece: each piece counts once.
        var points: [PaletteQuantiser.Point] = []
        for piece in distinct { for cluster in measures[piece.id]!.clusters { points.append(.init(lab: cluster.lab, weight: cluster.share / n)) } }
        let found = PaletteQuantiser.clusters(points, k: 12, merge: 0.05)
            .filter { $0.share >= 0.006 || ($0.share >= 0.002 && $0.lab.chroma > 0.08) }
        // Declared colours: one near a measured colour takes its place exactly; others join at the end.
        var entries: [(lab: OKLab, hex: String, weight: Double, source: String, names: [String])] = found.map { ($0.lab, $0.hex, $0.share, "measured", []) }
        for colour in declared.colours {
            guard let lab = OKLab(hex: colour.hex) else { continue }
            if let index = entries.indices.min(by: { entries[$0].lab.distance(lab) < entries[$1].lab.distance(lab) }), entries[index].lab.distance(lab) < 0.05 {
                if entries[index].source == "measured" { entries[index] = (lab, colour.hex, entries[index].weight, "measured+declared", [colour.name]) }
                else if !entries[index].names.contains(colour.name) { entries[index].names.append(colour.name) }
            } else if !entries.contains(where: { $0.hex == colour.hex }) {
                entries.append((lab, colour.hex, 0, "declared", [colour.name]))
            } else if let index = entries.firstIndex(where: { $0.hex == colour.hex }) {
                entries[index].names.append(colour.name)
            }
        }
        let measuredFirst = entries.enumerated().sorted { a, b in
            a.element.weight != b.element.weight ? a.element.weight > b.element.weight : a.offset < b.offset
        }.map(\.element).prefix(letters.count)
        let palette = measuredFirst.enumerated().map { index, entry -> Colour in
            let count = distinct.filter { piece in measures[piece.id]!.clusters.contains { $0.share >= 0.015 && $0.lab.distance(entry.lab) < 0.06 } }.count
            return Colour(id: letters[index], hex: entry.hex, lab: entry.lab, name: ColourNames.name(entry.lab), weight: entry.weight,
                          pieces: count, source: entry.source, declaredAs: entry.names)
        }
        var grounds: [String: Int] = [:]
        for piece in distinct { grounds[measures[piece.id]!.ground, default: 0] += 1 }
        func median(_ values: [Double]) -> Double { values.isEmpty ? 0 : values.sorted()[values.count / 2] }
        let margins = (0..<4).map { side in median(distinct.compactMap { measures[$0.id]?.margins[side] }) }
        var words: [String] = []
        for piece in distinct { for line in measures[piece.id]?.words ?? [] where !words.contains(line) { words.append(line) } }
        var measured = DesignMeasures(palette: palette, grounds: grounds, pieces: measures, margins: margins,
                                      ink: median(distinct.compactMap { measures[$0.id]?.ink }), fonts: fonts, declared: declared,
                                      words: Array(words.prefix(60)), credit: credit(in: texts), roles: [:])
        measured.roles = measuredRoles(measured, distinct: distinct)
        return measured
    }

    /// The ground each theme stands on (the colour most of that theme's pieces are framed in) and the heaviest
    /// colour that reads on it as text (4.5:1).
    static func measuredRoles(_ m: DesignMeasures, distinct: [DesignInventory.Piece]) -> [String: [String: String]] {
        var roles: [String: [String: String]] = [:]
        for theme in ["light", "dark"] {
            var votes: [String: Int] = [:]
            for piece in distinct {
                guard let measure = m.pieces[piece.id], let lab = OKLab(hex: measure.groundHex) else { continue }
                let isLight = measure.ground == "light" || (measure.ground == "colour" && lab.l >= 0.6)
                let isDark = measure.ground == "dark" || (measure.ground == "colour" && lab.l < 0.6)
                guard (theme == "light" && isLight) || (theme == "dark" && isDark) else { continue }
                if let nearest = m.palette.min(by: { $0.lab.distance(lab) < $1.lab.distance(lab) }), nearest.lab.distance(lab) < 0.08 {
                    votes[nearest.id, default: 0] += 1
                }
            }
            guard let ground = votes.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) })?.key,
                  let groundHex = m.colour(ground)?.hex else { continue }
            roles["background", default: [:]][theme] = ground
            let readable = m.palette.filter { $0.id != ground && $0.weight > 0 && Contrast.ratio($0.hex, groundHex) >= 4.5 }
            if let ink = readable.max(by: { $0.weight < $1.weight }) { roles["ink", default: [:]][theme] = ink.id }
        }
        return roles
    }

    /// "Designed by Mira Hale" and a link, in the folder's words (an about.txt, a README).
    static func credit(in texts: [String: String]) -> Credit? {
        for (file, text) in texts.sorted(by: { $0.key < $1.key }) {
            for match in DeclaredStyle.matches(#"(?im)^\s*(?:designed by|design by|designer\s*:|by\s*:)\s*([^\n—–|,]{2,60})"#, in: text) {
                let name = match[1].trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".-")))
                guard !name.isEmpty else { continue }
                let url = DeclaredStyle.matches(#"https?://[^\s)>\]]+"#, in: text).first?[0]
                return Credit(name: name, url: url, source: file)
            }
        }
        return nil
    }
}
