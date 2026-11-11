//  WHAT: One block of a piece, as the host's model writes it: what kind of thing it is and its words. The kit draws
//        each kind in the style; the model never says where a block goes, how big it is or what colour it takes.
//  PIN:  WORDS ONLY. A block carries text, items, a figure, rows, a label; never a size, a position or a colour, so
//        the same piece drawn in another style is that style's piece.

import Foundation

public struct PieceBlock: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// The piece's main line.
        case headline
        /// A short line over the headline: a section, a date, a category.
        case kicker
        /// A line under the headline that says more.
        case subhead
        /// The opening paragraph, larger than the body.
        case lead
        /// A paragraph.
        case body
        /// Things that belong together, as `items`.
        case list
        /// What happens, in order, as `items`.
        case steps
        /// One figure (`figure`) and what it measures (`text`).
        case stat
        /// Words someone said (`text`) and who (`by`), only when the person named them.
        case quote
        /// A boxed note: `title` and `text`.
        case callout
        /// Facts as `items` "Label: value": a date, a time, a place, a price.
        case details
        /// `rows` of cells, the first the header.
        case table
        /// A picture: `src` (a file the person gave) or a stand-in in the style's treatment, captioned by `alt`.
        case image
        /// What to do next: `label`, and `text` for where (a URL, an address).
        case cta
        /// The designer's mark, or `text` set as a wordmark.
        case logo
        /// A rule between blocks.
        case divider
        /// Small print at the foot.
        case footer

        /// A kind a model named loosely: "title" is a headline, "bullets" a list, "button" a cta; an unknown one body.
        public init(loose name: String) {
            let word = name.lowercased().filter { $0.isLetter }
            if let kind = Kind(rawValue: word) { self = kind; return }
            switch word {
            case "title", "heading", "headings", "h", "display", "name": self = .headline
            case "eyebrow", "overline", "tag", "label", "category", "section": self = .kicker
            case "subtitle", "subheading", "dek", "tagline", "strapline", "role": self = .subhead
            case "intro", "introduction", "standfirst", "summary": self = .lead
            case "paragraph", "text", "copy", "description", "content": self = .body
            case "bullets", "bulletlist", "points", "items", "features": self = .list
            case "numbered", "process", "howto", "timeline", "step": self = .steps
            case "number", "figure", "metric", "statistic", "stats": self = .stat
            case "quotation", "testimonial", "pullquote": self = .quote
            case "note", "highlight", "box", "aside", "notice": self = .callout
            case "info", "meta", "facts", "when", "where", "event", "contact", "detail": self = .details
            case "grid", "schedule", "prices", "pricing", "timetable": self = .table
            case "photo", "picture", "illustration", "img", "graphic", "visual": self = .image
            case "button", "action", "link", "calltoaction": self = .cta
            case "mark", "brand", "wordmark", "logotype": self = .logo
            case "rule", "separator", "hr", "line": self = .divider
            case "colophon", "footnote", "fineprint", "credits", "smallprint": self = .footer
            default: self = .body
            }
        }

        public init(from decoder: Decoder) throws {
            self.init(loose: (try? decoder.singleValueContainer().decode(String.self)) ?? "")
        }

        /// Kinds that open a piece: what the hero and the head of a grid hold.
        public var isHead: Bool { [.kicker, .headline, .subhead, .lead, .logo].contains(self) }
    }

    public var kind: Kind
    public var text: String?
    public var title: String?
    public var items: [String]
    public var figure: String?
    public var by: String?
    public var rows: [[String]]
    public var label: String?
    public var alt: String?
    public var src: String?

    public init(kind: Kind, text: String? = nil, title: String? = nil, items: [String] = [], figure: String? = nil, by: String? = nil,
                rows: [[String]] = [], label: String? = nil, alt: String? = nil, src: String? = nil) {
        self.kind = kind; self.text = text; self.title = title; self.items = items; self.figure = figure; self.by = by
        self.rows = rows; self.label = label; self.alt = alt; self.src = src
    }

    enum CodingKeys: String, CodingKey { case kind, text, title, items, figure, by, rows, label, alt, src }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decodeIfPresent(Kind.self, forKey: .kind)) ?? .body
        text = PieceLoose.string(c, .text)?.nonEmptyText
        title = PieceLoose.string(c, .title)?.nonEmptyText
        items = PieceLoose.list(c, .items, of: String.self).compactMap(\.nonEmptyText)
        // A model writes a list as a list, or as one string of lines.
        if items.isEmpty, let lines = PieceLoose.string(c, .items) {
            items = lines.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        figure = PieceLoose.string(c, .figure)?.nonEmptyText
        // The kit draws the dash; a model often writes its own ("—Seneca").
        by = PieceLoose.string(c, .by)?.trimmingCharacters(in: CharacterSet(charactersIn: "-–—~ ").union(.whitespacesAndNewlines)).nonEmptyText
        rows = ((try? c.decodeIfPresent([PieceLoose.Element<[String]>].self, forKey: .rows)) ?? nil)?.compactMap(\.value).filter { !$0.isEmpty } ?? []
        label = PieceLoose.string(c, .label)?.nonEmptyText
        alt = PieceLoose.string(c, .alt)?.nonEmptyText
        src = PieceLoose.string(c, .src)?.nonEmptyText
        // A headline written as `title` is still a headline.
        if [.headline, .kicker, .subhead, .lead, .body, .footer].contains(kind), text == nil, let title { text = title; self.title = nil }
        if kind == .cta, label == nil, let text { label = text; self.text = nil }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(title, forKey: .title)
        if !items.isEmpty { try c.encode(items, forKey: .items) }
        try c.encodeIfPresent(figure, forKey: .figure)
        try c.encodeIfPresent(by, forKey: .by)
        if !rows.isEmpty { try c.encode(rows, forKey: .rows) }
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(alt, forKey: .alt)
        try c.encodeIfPresent(src, forKey: .src)
    }

    /// Every word the block says, for counting and for the checks.
    public var words: String {
        ([text, title, figure, by, label, alt].compactMap { $0 } + items + rows.flatMap { $0 }).joined(separator: " ")
    }
}
