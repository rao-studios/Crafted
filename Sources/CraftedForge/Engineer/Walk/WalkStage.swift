//  WHAT: The walk: a brief from the README and manifests, then a card for every source file, leaves first along the
//        import graph, entry files last. Each card is grounded against its file's lines (CardGrounding) and cached by
//        the file's hash and the prompt's version, so an updated project re-reads only what changed.
//  IN:   The inventory (redacted texts only).
//  OUT:  brief.json, cards.json, graph.json; progress: files read of total, the file being read, use cases spotted.

import CraftedCore
import Foundation

struct WalkStage {
    let context: ForgeContext
    let inventory: Inventory

    var ask: EngineerAsk { EngineerAsk(context: context) }

    func brief() async throws -> ProjectBrief {
        var parts: [String] = []
        for file in inventory.files where file.verdict == .manifest || (file.verdict == .doc && file.path.lowercased().hasPrefix("readme")) {
            guard let text = inventory.text(file.path) else { continue }
            parts.append("--- \(file.path)\n" + String(text.prefix(6000)))
        }
        let languages = Swift.Set(inventory.with(.read).compactMap { $0.language?.rawValue }).sorted()
        let sources = inventory.with(.read).map(\.path)
        let user = "The project's README and manifests:\n\n" + (parts.isEmpty ? "(none)" : parts.joined(separator: "\n\n"))
            + "\n\nIts source files (\(languages.joined(separator: ", "))): " + sources.joined(separator: ", ")
        return try await ask.object(.brief, user, as: ProjectBrief.self, budget: .reduce) { brief in
            var problems: [String] = []
            if brief.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { problems.append("summary is empty") }
            if brief.summary.count > 2400 { problems.append("summary is \(brief.summary.count) characters: keep it under 400 tokens") }
            return problems
        }
    }

    func cards(brief: ProjectBrief, order: [String], graph: ImportGraph) async throws -> [FileCard] {
        let cache = context.cache.ledger("cards")
        var cards: [FileCard] = []
        var spotted = 0
        for (index, path) in order.enumerated() {
            try context.checkCancellation()
            guard let file = inventory.file(path), let sha = file.sha256 else { continue }
            let lines = inventory.lines(path)
            let rules = (file.language ?? .other).rules
            let outline = rules.outline(lines)
            let effects = rules.effects(lines)
            let chunks = SourceText.chunks(lines, outline: outline)
            context.progress("walk", "Reading \(path)" + (chunks.count > 1 ? " (\(chunks.count) parts)" : ""),
                             fraction: Double(index) / Double(max(order.count, 1)),
                             counts: ["filesRead": index, "filesTotal": order.count, "useCases": spotted])
            var parts: [FileCard] = []
            for (part, range) in chunks.enumerated() {
                let user = prompt(brief: brief, file: file, lines: lines, range: range, part: part, of: chunks.count,
                                  imports: graph.imports[path] ?? [], outline: outline, effects: effects)
                let key = "\(sha)-\(EngineerPrompts.Purpose.card.rawValue)-\(EngineerPrompts.version)-\(part)"
                var card = try await ask.object(.card, user, as: FileCard.self, budget: .card, ledger: cache, key: key, repairs: 1) { card in
                    CardGrounding.isMostlyUngrounded(card, lines: lines) ? CardGrounding.problems(card, lines: lines) : []
                }
                card = CardGrounding.strike(card, lines: lines)
                parts.append(card)
            }
            guard var card = merge(parts) else { continue }
            card.path = path
            card.sha256 = sha
            card.language = file.language?.rawValue ?? "other"
            card.lines = lines.count
            spotted += card.spotted.count
            cards.append(card)
            if !card.struck.isEmpty {
                context.note("\(path): struck \(card.struck.count) ungrounded item\(card.struck.count == 1 ? "" : "s") from its card.")
            }
        }
        context.progress("walk", "Read \(cards.count) files", fraction: 1, counts: ["filesRead": cards.count, "filesTotal": order.count, "useCases": spotted])
        return cards
    }

    func prompt(brief: ProjectBrief, file: InventoryFile, lines: [String], range: ClosedRange<Int>, part: Int, of parts: Int,
                imports: [String], outline: [OutlineItem], effects: [EffectLine]) -> String {
        var text = brief.prefix + "\n\n"
        text += "File: \(file.path) (\(file.language?.rawValue ?? "text"), \(lines.count) lines)"
        if parts > 1 { text += ", part \(part + 1) of \(parts): lines \(range.lowerBound)-\(range.upperBound)" }
        text += "\n"
        if !imports.isEmpty { text += "Imports in the project: " + imports.joined(separator: ", ") + "\n" }
        if !outline.isEmpty { text += "Outline:\n" + outline.map { "  \($0.line): \($0.text)" }.joined(separator: "\n") + "\n" }
        if !effects.isEmpty { text += "Lines code found touching the world:\n" + effects.map { "  \($0.line) \($0.kind): \($0.detail)" }.joined(separator: "\n") + "\n" }
        text += "\nListing:\n" + SourceText.numbered(lines, from: range.lowerBound, through: range.upperBound)
        return text
    }

    /// One card from a file's parts: lists joined, the first part's role and summary.
    func merge(_ parts: [FileCard]) -> FileCard? {
        guard var card = parts.first else { return nil }
        for part in parts.dropFirst() {
            card.entities += part.entities; card.operations += part.operations; card.rules += part.rules
            card.inputs += part.inputs; card.outputs += part.outputs; card.effects += part.effects
            card.depends += part.depends; card.spotted += part.spotted; card.struck += part.struck
            card.importance = max(card.importance, part.importance)
        }
        return card
    }
}
