//  WHAT: A card held to the file it describes: every cited range exists, every operation's name is on its lines,
//        every number and quoted string in a rule occurs in its range. What fails is struck, with a sentence saying
//        why; a card that is mostly ungrounded is sent back to the model instead.
//  OUT:  The walk (`problems` as the structured ask's check, `strike` on the accepted card); tests.
//  PIN:  THE LINES ARE THE TRUTH. Nothing a model says about a file survives unless the file's own lines show it.

import Foundation

public enum CardGrounding {
    /// Every ungrounded item of `card` against `lines`, one sentence each.
    public static func problems(_ card: FileCard, lines: [String]) -> [String] {
        var problems: [String] = []
        for entity in card.entities {
            if let why = rangeProblem(entity.lines, lines) { problems.append("entity \(entity.name): \(why)") }
        }
        for operation in card.operations {
            if let why = rangeProblem(operation.lines, lines) {
                problems.append("operation \(operation.name): \(why)")
            } else if let text = SourceText.cut(lines, operation.lines), !text.contains(bareName(operation.name)) {
                problems.append("operation \(operation.name) is not named on lines \(operation.lines)")
            }
        }
        for rule in card.rules {
            if let why = rangeProblem(rule.lines, lines) {
                problems.append("rule \"\(rule.statement.prefix(40))\": \(why)")
            } else if let text = SourceText.cut(lines, rule.lines) {
                for token in literals(in: [rule.statement, rule.formula ?? ""].joined(separator: " ")) where !occurs(token, in: text) {
                    problems.append("rule \"\(rule.statement.prefix(40))\" says \(token), which is not on lines \(rule.lines)")
                }
            }
        }
        for effect in card.effects {
            if let range = effect.lines, let why = rangeProblem(range, lines) { problems.append("effect \(effect.kind): \(why)") }
        }
        return problems
    }

    /// Whether the card is too ungrounded to keep: more than half its cited items fail.
    public static func isMostlyUngrounded(_ card: FileCard, lines: [String]) -> Bool {
        let items = card.entities.count + card.operations.count + card.rules.count
        guard items > 0 else { return false }
        let failing = Swift.Set(problems(card, lines: lines).map { $0.split(separator: ":").first.map(String.init) ?? $0 }).count
        return failing * 2 > items
    }

    /// `card` with every ungrounded item struck and listed in `struck`.
    public static func strike(_ card: FileCard, lines: [String]) -> FileCard {
        var card = card
        var struck: [String] = []
        card.entities = card.entities.filter { entity in
            guard let why = rangeProblem(entity.lines, lines) else { return true }
            struck.append("entity \(entity.name): \(why)"); return false
        }
        card.operations = card.operations.filter { operation in
            if let why = rangeProblem(operation.lines, lines) { struck.append("operation \(operation.name): \(why)"); return false }
            if let text = SourceText.cut(lines, operation.lines), !text.contains(bareName(operation.name)) {
                struck.append("operation \(operation.name) is not named on lines \(operation.lines)"); return false
            }
            return true
        }
        card.rules = card.rules.filter { rule in
            if let why = rangeProblem(rule.lines, lines) { struck.append("rule \"\(rule.statement.prefix(40))\": \(why)"); return false }
            guard let text = SourceText.cut(lines, rule.lines) else { return false }
            let missing = literals(in: [rule.statement, rule.formula ?? ""].joined(separator: " ")).filter { !occurs($0, in: text) }
            if !missing.isEmpty { struck.append("rule \"\(rule.statement.prefix(40))\" cites \(missing.joined(separator: ", ")), not on lines \(rule.lines)") }
            return missing.isEmpty
        }
        card.effects = card.effects.filter { effect in
            guard let range = effect.lines, let why = rangeProblem(range, lines) else { return true }
            struck.append("effect \(effect.kind): \(why)"); return false
        }
        card.struck += struck
        return card
    }

    static func rangeProblem(_ range: LineRange, _ lines: [String]) -> String? {
        if range.start < 1 || range.end > lines.count { return "lines \(range) are not in the file (it has \(lines.count))" }
        return nil
    }

    /// `convert_length(value, …)` → `convert_length`; `Converter.convert` → `convert`.
    static func bareName(_ name: String) -> String {
        let head = name.split(whereSeparator: { $0 == "(" || $0 == " " }).first.map(String.init) ?? name
        return head.split(separator: ".").last.map(String.init) ?? head
    }

    /// The numbers and quoted strings a rule says: what must occur in its lines.
    static func literals(in text: String) -> [String] {
        var found: [String] = []
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let numbers = try? NSRegularExpression(pattern: #"(?<![\w.])\d+(?:\.\d+)?(?![\w])"#) {
            for match in numbers.matches(in: text, range: full) { found.append(ns.substring(with: match.range)) }
        }
        if let quoted = try? NSRegularExpression(pattern: #"["'`]([^"'`]{1,60})["'`]"#) {
            for match in quoted.matches(in: text, range: full) { found.append(ns.substring(with: match.range(at: 1))) }
        }
        return Array(Swift.Set(found)).sorted()
    }

    /// Whether `token` occurs in `text`; a number also as written with a trailing `.0` or without its leading zero.
    static func occurs(_ token: String, in text: String) -> Bool {
        if text.contains(token) { return true }
        guard let value = Double(token) else { return false }
        let variants = [String(value), value == value.rounded() ? String(Int(value)) : nil, token.hasPrefix("0.") ? String(token.dropFirst()) : nil].compactMap { $0 }
        return variants.contains { text.contains($0) }
    }
}
