//  WHAT: What the host's model is told: how a piece is written (its blocks and what each holds), how this style speaks,
//        a worked example on another subject to copy the shape of, and the keys. Then what to write, what to change,
//        or what to fix. (After PlateAgent's PlateSheetDraft.)
//  PIN:  THE EXAMPLE IS ANOTHER SUBJECT'S. A local model copies the example it is shown, so it is a bakery's.
//  PIN:  NEVER AN INVENTED FACT. A date, a price, a place or a name is the person's (`content`, the ask) or it is not
//        on the piece; a quote names who said it only when the person did.

import AtelierKit
import Foundation

enum PieceDraft {
    static func rules(_ style: AtelierStyle) -> String {
        var voice: [String] = []
        if !style.voice.tone.isEmpty { voice.append("Tone: \(style.voice.tone.joined(separator: ", ")).") }
        if let headline = style.voice.headline { voice.append("Headlines: \(headline)") }
        if !style.voice.vocabulary.isEmpty { voice.append("Words it uses: \(style.voice.vocabulary.prefix(12).joined(separator: ", ")).") }
        if !style.voice.avoid.isEmpty { voice.append("Words it never uses: \(style.voice.avoid.prefix(12).joined(separator: ", ")).") }
        if !style.voice.samples.isEmpty { voice.append("Lines from the designer's own pieces, for their rhythm (never copy them): " + style.voice.samples.prefix(5).map { "\"\($0)\"" }.joined(separator: "; ") + ".") }
        let formats = PieceFormat.allCases.map { "\($0.rawValue) (\($0.blockLimit) blocks a page\($0.maxPages > 1 ? ", up to \($0.maxPages) pages" : ""))" }.joined(separator: ", ")
        return """
        You write one piece of graphic design as words in blocks. The kit draws it in \(style.credit.designer)'s style, \(style.name): every colour, face, size and place is the style's. You decide only what the piece says and which blocks say it. Answer with one JSON object: {"title", "format", "pages": [{"blocks": [...]}]}.

        How a good piece reads:
        - One message, said at three distances: a headline seen from across a room, a line or two that says more, and the facts a person acts on.
        - `title` names the piece (its file's name); it is not drawn.
        - `format` is one of: \(formats).
        - Each page's `blocks`, in reading order. The first page has one `headline`. Fewer blocks read better than more.
        - `kind` says what a block is:
          - "headline": `text`, at most 60 characters; "kicker": `text`, a short line over it (a date, a series, a category), at most 40.
          - "subhead": `text`, one line that says more, at most 120; "lead": `text`, an opening paragraph, at most 280; "body": `text`, a paragraph (a blank line between paragraphs), at most 700.
          - "list": `title` (optional) and `items`, two to six lines; "steps": `title` (optional) and `items`, in order.
          - "stat": `figure` ("72%", "3×", "1987"; at most 8 characters) and `text`, what it measures.
          - "quote": `text`, and `by` only when the person named who said it.
          - "callout": `title` and `text`: one thing a reader must not miss.
          - "details": `items`, each "Label: value" (Date: …, Time: …, Place: …, Price: …).
          - "table": `rows`, the first the header, at most 6 rows of 4 cells.
          - "image": `alt`, what the picture shows; `src` only when the person gave a picture file.
          - "cta": `label`, what to do (at most 28 characters), and `text`, where (a URL, an address).
          - "logo": the designer's mark, or `text` set as a wordmark; "divider": a rule; "footer": `text`, small print.
        - Use the person's own words from what they gave as written. Never invent a date, a time, a price, a place, a name or a URL: leave the block out instead.
        - Never write the designer's credit: the kit adds it.
        \(voice.isEmpty ? "" : "\nHow this style speaks:\n" + voice.map { "- " + $0 }.joined(separator: "\n"))
        """
    }

    /// A piece on another subject: what the model copies the shape of.
    static let example = """
    {"title": "Sourdough mornings", "format": "flyer", "pages": [{"blocks": [
      {"kind": "kicker", "text": "Saturdays in May"},
      {"kind": "headline", "text": "Bread that takes its time"},
      {"kind": "subhead", "text": "A morning class on starters, folds and a slow rise"},
      {"kind": "list", "title": "You leave with", "items": ["a jar of starter", "two loaves", "the method on one card"]},
      {"kind": "details", "items": ["Date: Saturday 10 May", "Time: 8 to 11 am", "Place: the bakery's back room"]},
      {"kind": "cta", "label": "Book a place", "text": "bakery.example/class"},
      {"kind": "footer", "text": "Twelve places a class. Flour and aprons provided."}]}]}
    """

    static func system(_ style: AtelierStyle) -> String {
        rules(style) + "\n\nA piece on another subject, to copy the shape of and never the words:\n" + example
    }

    static func reviseSystem(_ style: AtelierStyle) -> String {
        rules(style) + "\n\nYou are fixing a piece you wrote, after it was drawn and measured. Keep every block the findings do not name; make the fewest changes that clear every finding. Answer with the whole piece, fixed."
    }

    static func draft(ask: String?, input: AtelierAgent.Input, style: AtelierStyle) -> String {
        var parts: [String] = []
        if let ask = ask?.nonEmptyText { parts.append("The person asked: \"\(ask)\"") }
        if let brief = input.brief?.nonEmptyText { parts.append("What it is for: \(brief)") }
        if let content = input.content?.nonEmptyText { parts.append("The person's own words, to set as given:\n\(content)") }
        let format = input.format ?? .poster
        var shape = "Write a \(format.title)"
        if let pages = input.pages, format.maxPages > 1 { shape += " of \(min(max(pages, 1), format.maxPages)) pages" }
        shape += input.format == nil ? " (or the format the ask names)." : "."
        parts.append(shape + " Say it in your own words where the person gave none, and never invent a fact.")
        return parts.joined(separator: "\n\n")
    }

    /// What a brief asks of a piece drawn before.
    static func change(_ piece: Piece, brief: String) -> String {
        "The piece, as drawn before:\n\(piece.json)\n\nWhat to change: \(brief)\n\nWrite the whole piece again, changed as asked and nothing else."
    }

    static func revise(_ piece: Piece, findings: [PieceFinding]) -> String {
        "The piece you wrote:\n\(piece.json)\n\nWhat the page measured:\n" + findings.prefix(16).map { "- " + $0.sentence }.joined(separator: "\n")
            + "\n\nWrite the whole piece again, fixed."
    }

    /// The keys, as JSON Schema.
    static let schema: Data = {
        let text: [String: Any] = ["type": "string"]
        let texts: [String: Any] = ["type": "array", "items": text]
        let block: [String: Any] = ["type": "object", "required": ["kind"], "properties": [
            "kind": ["type": "string", "enum": PieceBlock.Kind.allCases.map(\.rawValue)], "text": text, "title": text, "items": texts,
            "figure": text, "by": text, "rows": ["type": "array", "items": texts], "label": text, "alt": text, "src": text]]
        let page: [String: Any] = ["type": "object", "required": ["blocks"], "properties": ["blocks": ["type": "array", "items": block]]]
        let piece: [String: Any] = ["type": "object", "required": ["title", "pages"], "properties": [
            "title": text, "format": ["type": "string", "enum": PieceFormat.allCases.map(\.rawValue)], "pages": ["type": "array", "items": page]]]
        return (try? JSONSerialization.data(withJSONObject: piece, options: [.sortedKeys])) ?? Data("{}".utf8)
    }()
}
