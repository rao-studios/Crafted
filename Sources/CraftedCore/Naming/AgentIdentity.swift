//  WHAT: Every name a generated agent carries, derived from the one name a person edits: the display name, the
//        Swift base, the package, its targets and type, the roster record, and the word Craft calls it by.
//  IN:   The listing form's name (and word, when edited apart), an interpretation's suggestion.
//  OUT:  The package assembler (identity tokens), the listing, the store validator.
//  PIN:  RENAME IS RE-ASSEMBLY. Identity appears only in a template's fixed and generated files, never in a model's
//        slot bodies, so a new name is a new assembly of the same artefacts, never an edit of model-written code.
//
//        "Invoice Totals" → base InvoiceTotals · package, agent target, library, type InvoiceTotalsAgent ·
//        InvoiceTotalsCore (engineer) / InvoiceTotalsKit (designer) · record invoiceTotalsRecord · word invoicetotals

import Foundation

public struct AgentIdentity: Codable, Sendable, Equatable, Hashable {
    /// What a person reads: "Invoice Totals".
    public var display: String
    /// Pascal case, ASCII, starts with a letter: "InvoiceTotals".
    public var base: String
    /// What Craft and a model call it by: `^[a-z][a-z0-9]{1,31}$`.
    public var word: String

    public init(display: String, base: String, word: String) {
        self.display = display
        self.base = base
        self.word = word
    }

    public var package: String { base + "Agent" }
    public var agentTarget: String { package }
    public var typeName: String { package }
    public var coreTarget: String { base + "Core" }
    public var kitTarget: String { base + "Kit" }
    public var lowerBase: String { base.prefix(1).lowercased() + base.dropFirst() }
    public var recordName: String { lowerBase + "Record" }

    /// Every name from one display name. `word` is kept when given and valid, else derived.
    public static func derive(display: String, word: String? = nil) -> AgentIdentity {
        let trimmed = display.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = trimmed.isEmpty ? "Crafted Agent" : String(trimmed.prefix(64))
        let base = Self.base(from: shown)
        let chosen = word.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let word = (chosen.flatMap { AgentNameRules.wordProblem($0) == nil ? $0 : nil }) ?? Self.word(from: base)
        return AgentIdentity(display: shown, base: base, word: word)
    }

    /// "3D Größe & Co" → "A3DGrosseCo"; "Invoice Agent" → "Invoice" (the package adds Agent).
    public static func base(from display: String) -> String {
        let latin = display.applyingTransform(.toLatin, reverse: false) ?? display
        let folded = latin.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "ß", with: "ss")
        let words = folded.split(whereSeparator: { !($0.isASCII && ($0.isLetter || $0.isNumber)) })
        var base = words.map { word -> String in
            let text = String(word)
            return text.prefix(1).uppercased() + text.dropFirst()
        }.joined()
        if base.hasSuffix("Agent"), base.count > 5 { base.removeLast(5) }
        if base.isEmpty { base = "Crafted" }
        if let first = base.first, !first.isLetter { base = "A" + base }
        return String(base.prefix(48))
    }

    /// "InvoiceTotals" → "invoicetotals": lowercase letters and digits, starting with a letter, 2 to 32 long.
    public static func word(from base: String) -> String {
        var word = base.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        if let first = word.first, !first.isLetter { word = "a" + word }
        if word.count < 2 { word += "agent" }
        word = String(word.prefix(32))
        if AgentNameRules.reserved.contains(word) { word = String((word + "agent").prefix(32)) }
        return word
    }
}
