//  WHAT: New pieces in one designer's style, as a Granite agent package: posters, flyers, brochures, one-pagers,
//        social cards, stories, business cards, slides and banners. The host's model writes a piece as blocks of words;
//        the kit lays them out in WebKit in the style, fits the type, measures what still overflows, and the model cuts
//        until it measures clean. Written as a PNG at 2x, or a paged PDF, carrying the spec it was drawn from and the
//        designer's credit, so it redraws, or changes, without a model.
//  PIN:  THE MODEL SAYS, THE KIT PLACES. A piece is words only; the engines, the type, the colours, the motifs and the
//        mark are the style's. A local model writes a good piece; it is never asked to place one.
//  PIN:  CREDIT EVERYWHERE. The summary, the guide, every answer's notes, the file's metadata and a colophon on the
//        piece name the designer; a call may turn the colophon off only when the style lets it.
//  PIN:  NOTHING UNTIL A CALL. The WebKit page and the style are made on the first call (`PieceCompute`).

import AtelierKit
import Foundation
import GraniteAgents

public struct AtelierAgent: GraniteAgentPackage {
    public struct Input: Codable, Sendable {
        /// What the piece is for, in a sentence: the event, the offer, the announcement.
        public var brief: String?
        /// What it is: poster, flyer, brochure, onepager, socialcard, story, businesscard, slide, banner.
        public var format: PieceFormat?
        /// The person's own words to set: names, dates, prices, a paragraph. Used as given, never invented.
        public var content: String?
        /// A page size: "1200x1600" in CSS pixels, or a paper ("a4", "letter", "square", "16:9").
        public var size: String?
        /// How many pages, for a brochure or a deck of slides.
        public var pages: Int?
        /// light or dark; the designer's own ground when left out.
        public var theme: PieceTheme?
        /// A piece drawn before, as its PNG or PDF (each carries its spec) or a spec's JSON: drawn again with no model,
        /// or changed as `brief` asks.
        public var spec: String?
        /// Where to write it: a .png (one a page) or a .pdf; pieces/<title>.png (or .pdf for several pages) when left out.
        public var output: String?
        /// How many times the model may fix what the page measured; 3 when left out.
        public var rounds: Int?
        /// false to leave the colophon off, when the designer allows it.
        public var credit: Bool?
        /// The host's folder.
        public var directory: String?

        public init(brief: String? = nil, format: PieceFormat? = nil, content: String? = nil, size: String? = nil, pages: Int? = nil,
                    theme: PieceTheme? = nil, spec: String? = nil, output: String? = nil, rounds: Int? = nil, credit: Bool? = nil,
                    directory: String? = nil) {
            self.brief = brief; self.format = format; self.content = content; self.size = size; self.pages = pages; self.theme = theme
            self.spec = spec; self.output = output; self.rounds = rounds; self.credit = credit; self.directory = directory
        }
    }

    public typealias Event = PieceFrame
    public typealias Output = PieceResult
    public typealias Compute = PieceCompute

    public static let word = "atelierword"
    /// The agent's name as a person reads it.
    public static let display = "Atelier Template"
    public static let summary = "draws posters, flyers, brochures, one-pagers, social cards, stories, business cards, slides and banners in \(DesignerCredit.style), the design system of \(DesignerCredit.designer), as a PNG or a paged PDF; every piece credits \(DesignerCredit.designer)."
    public static let fields = [
        "brief": "what the piece is for, in a sentence: the event, the offer, the announcement",
        "format": "poster, flyer, brochure, onepager, socialcard, story, businesscard, slide or banner",
        "content": "the person's own words to set (names, dates, places, prices, a paragraph), used as given",
        "size": "a page size, \"1200x1600\" in CSS pixels or a paper: a4, a5, letter, square, 16:9; the format's own when left out",
        "pages": "how many pages, for a brochure or a deck of slides",
        "theme": "light or dark; the designer's own ground when left out",
        "spec": "a piece's PNG or PDF from an earlier call (it carries its spec), to draw again; with a brief, changed as the brief asks",
        "output": "where to write it: a .png or a .pdf; pieces/<title>.png when left out",
        "rounds": "how many times to fix what the page measured; 3 when left out",
        "credit": "false to leave the colophon off, when the designer allows it",
    ]
    public static let guide = """
        Ask \(word) for a new piece in \(DesignerCredit.designer)'s style, \(DesignerCredit.style): a poster, flyer, brochure, \
        one-pager, social card, story, business card, slide or banner. Set `format`, say in `brief` what it is for, and put \
        the person's own words in `content` (names, dates, places, prices, a paragraph): they are set as given, and nothing \
        the person did not say is made up. The model writes the piece as blocks (headline, kicker, subhead, lead, body, \
        list, steps, stat, quote, callout, details, table, image, cta, logo, divider, footer); the style decides every \
        colour, face, size and place. It measures the page in WebKit, sets the type smaller where it must, and has the \
        model cut what still does not fit, up to `rounds`; a call takes a minute or two. It answers with a PNG at 2x, or a \
        paged PDF for a brochure or a deck, each carrying the spec it was drawn from: to change a piece, call again with \
        `spec` set to its file and say the change in `brief`. Every piece carries a colophon crediting \
        \(DesignerCredit.designer); `credit: false` leaves it off when the designer allows it. Pictures are the person's \
        own, given as an image block's `src`; otherwise the piece shows where a picture goes. Not for charts, photographs \
        or logos of other brands.
        """
    public static let makes = [
        AgentMake(kind: "piece",
                  what: "a poster, flyer, brochure, one-pager, social card, story, business card, slide or banner in \(DesignerCredit.style) by \(DesignerCredit.designer), as a PNG at 2x or a paged PDF",
                  into: ["pieces/*", "*", "*/*"],
                  never: "a picture, a logo or a design of anyone else's; never a piece without its credit when the designer requires one"),
    ]
    /// One WebKit page draws every piece: calls take turns.
    public static let lanes: Int? = 1

    public static func compute() async throws -> PieceCompute { await MainActor.run { PieceCompute() } }
    public static func output(from events: [PieceFrame]) -> PieceResult? { events.compactMap(\.result).last }

    public init() {}

    public func run(_ input: Input, context: Context) -> AsyncThrowingStream<PieceFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await PieceLoop(input: input, context: context, yield: { continuation.yield($0) }).run()
                    continuation.yield(.written(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
