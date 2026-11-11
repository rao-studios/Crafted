//  WHAT: The listing the forge suggests for a style agent: "<Style> by <Designer>", a tagline, keywords, the graphics
//        category, the designer's credit, and the fields the template's input takes. The coder model names the style;
//        code makes everything else, and holds the model's words to the store's rules.
//  OUT:  PipelineOutcome.listing (merged under the person's edits by the store).

import CraftedCore
import Foundation

public enum DesignerWords {
    /// The template's input, as the store shows it.
    public static let fields: [ListingField] = [
        .init(name: "brief", type: "string", required: false, note: "what the piece is for, in a sentence"),
        .init(name: "format", type: "choice", required: false, note: "poster, flyer, brochure, onepager, socialcard, story, businesscard, slide or banner"),
        .init(name: "content", type: "string", required: false, note: "the person's own words to set, used as given"),
        .init(name: "size", type: "string", required: false, note: "a page size: 1200x1600, a4, letter, square, 16:9"),
        .init(name: "pages", type: "integer", required: false, note: "how many pages, for a brochure or a deck"),
        .init(name: "theme", type: "choice", required: false, note: "light or dark"),
        .init(name: "spec", type: "path", required: false, note: "a piece drawn before (its PNG or PDF), to draw again or change"),
        .init(name: "output", type: "path", required: false, note: "where to write the PNG or PDF"),
        .init(name: "rounds", type: "integer", required: false, note: "how many times to fix what the page measured"),
        .init(name: "credit", type: "boolean", required: false, note: "false to leave the colophon off, when the designer allows it"),
    ]

    public static func ask(_ context: ForgeContext, style: DesignerStyle, folder: String) async throws -> WordsAnswer? {
        let roles = style.type.roles
        let user = """
        The designer: \(style.credit.designer). Their folder is called "\(folder)".
        Colour: \(style.colour.palette.prefix(5).compactMap(\.name).joined(separator: ", ")).
        Type: display \(roles["display"]?.class ?? "sans"), body \(roles["body"]?.class ?? "sans").
        Tone: \(style.voice.tone.joined(separator: ", ")).
        Name the style and write the listing's tagline and keywords.
        """
        let prompt = try DesignerPrompts.prompt(.words, user: user)
        let key = "\(DesignerPrompts.Purpose.words.rawValue).\(DesignerPrompts.version)-\(prompt.hash.prefix(16))"
        if let kept = context.ledger.get(WordsAnswer.self, key) { return kept }
        do {
            let answer = try await context.ask.object(.coder, prompt, as: WordsAnswer.self, budget: .words, check: check)
            try context.ledger.put(answer, key)
            return answer
        } catch let error as ForgeError {
            if case .model = error {
                context.finding(Finding(.fallback, "The listing's words did not hold after their repairs; the folder's name names the style."))
                return nil
            }
            throw error
        }
    }

    public static func check(_ answer: WordsAnswer) -> [String] {
        var problems: [String] = []
        let style = answer.style.trimmingCharacters(in: .whitespacesAndNewlines)
        if style.isEmpty || style.count > 40 { problems.append("the style's name is one to three words, at most 40 characters.") }
        if answer.tagline.isEmpty || answer.tagline.count > ListingRules.taglineLimit { problems.append("the tagline is one sentence of at most 120 characters.") }
        return problems
    }

    /// The listing: the style's name (the model's, else the folder's), the designer's credit, the template's fields.
    public static func listing(style name: String, answer: WordsAnswer?, credit: DesignerStyle.Credit) -> AgentListing {
        let display = String("\(name) by \(credit.designer)".prefix(ListingRules.nameLimit))
        let identity = AgentIdentity.derive(display: display)
        var keywords = (answer?.keywords ?? []).compactMap(ListingRules.keyword(from:))
        for extra in ["poster", "flyer", "design system", "brochure", "social card"] where keywords.count < 6 && !keywords.contains(extra) { keywords.append(extra) }
        let tagline = answer.map { String($0.tagline.prefix(ListingRules.taglineLimit)) }
            ?? String("Posters, flyers, brochures, cards and slides in \(name), the design system of \(credit.designer).".prefix(ListingRules.taglineLimit))
        return AgentListing(name: display, word: identity.word, tagline: tagline, category: .graphics, keywords: Array(keywords.prefix(ListingRules.keywordLimit)),
                            platforms: ["macOS 26"], license: .mit, credit: ListingCredit(designer: credit.designer, url: credit.url), fields: fields)
    }

    /// A style's name from a folder's: "velvet-night" → "Velvet Night".
    public static func name(folder: String) -> String {
        let words = folder.split { !$0.isLetter && !$0.isNumber }.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return words.isEmpty ? "House Style" : words.joined(separator: " ")
    }
}
