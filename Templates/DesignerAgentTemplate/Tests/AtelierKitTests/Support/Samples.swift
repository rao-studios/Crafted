import AtelierKit
import Foundation

/// A neutral piece for each format, and the styles the kit is held to: the package's own and two very different
/// fixtures (Fixtures/Styles: Ink Press, light, a bundled italic serif, dense, square; Neon Dusk, dark, a geometric
/// sans in capitals, sparse, round, centred). Paper and Ink, the template's own style, is a fixture too: a test that
/// holds the kit to one style's particulars uses a fixture, never "bundled", which is a designer's in a made package.
enum Samples {
    static let styles = ["bundled", "ink-press", "neon-dusk"]

    static func book(_ name: String) throws -> StyleBook {
        if name == "bundled" { return try AtelierResources.book() }
        return try StyleBook.load(folder: folder(name))
    }

    static func folder(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Styles/\(name)", isDirectory: true)
    }

    static func piece(_ format: PieceFormat) -> Piece {
        func b(_ kind: PieceBlock.Kind, _ text: String? = nil, title: String? = nil, items: [String] = [], figure: String? = nil, label: String? = nil, alt: String? = nil) -> PieceBlock {
            PieceBlock(kind: kind, text: text, title: title, items: items, figure: figure, label: label, alt: alt)
        }
        let details = b(.details, items: ["Date: 14 and 15 June", "Time: 10 am to 6 pm", "Place: Canal Yard"])
        let blocks: [[PieceBlock]]
        switch format {
        case .poster:
            blocks = [[b(.kicker, "Spring programme"), b(.headline, "Open studios"), b(.subhead, "Twelve artists, one weekend, every door open"),
                       details, b(.cta, "openstudios.example", label: "Plan your visit"), b(.footer, "Free entry. Step-free access throughout.")]]
        case .flyer:
            blocks = [[b(.kicker, "Spring programme"), b(.headline, "Open studios"), b(.lead, "Twelve artists open their doors for one weekend: see the work, meet the people who make it."),
                       b(.list, title: "Inside", items: ["printmaking and letterpress", "ceramics and glaze tests", "a reading room"]),
                       details, b(.cta, "openstudios.example", label: "Plan your visit"), b(.footer, "Free entry.")]]
        case .brochure:
            blocks = [[b(.kicker, "Spring programme"), b(.headline, "Open studios"), b(.subhead, "A weekend guide"), b(.image, alt: "the yard at opening"), b(.footer, "Canal Yard, 14 and 15 June")],
                      [b(.headline, "How the weekend runs"), b(.body, "Each studio keeps its own hours within the day. Start anywhere: the map at the gate shows who is open and what they are making."),
                       b(.steps, items: ["pick up a map at the gate", "follow the yellow doors", "sign the book on the way out"]),
                       b(.stat, "studios open", figure: "12"), b(.quote, "Come for the work, stay for the conversation."), details]]
        case .onepager:
            blocks = [[b(.kicker, "Spring programme"), b(.headline, "Open studios"), b(.lead, "Twelve artists open their doors for one weekend."),
                       b(.body, "Each studio keeps its own hours. The map at the gate shows who is open and what they are making; the reading room stays open late on Saturday."),
                       b(.list, title: "Inside", items: ["printmaking", "ceramics", "a reading room"]), b(.stat, "studios", figure: "12"), b(.stat, "years running", figure: "9"),
                       b(.callout, "Bring cash for the print sale: the studios take no cards.", title: "Note"), details, b(.footer, "Free entry. Step-free access.")]]
        case .socialcard:
            blocks = [[b(.kicker, "14 and 15 June"), b(.headline, "Open studios"), b(.subhead, "Twelve artists, one weekend"), b(.cta, label: "Plan your visit")]]
        case .story:
            blocks = [[b(.kicker, "14 and 15 June"), b(.headline, "Open studios"), b(.subhead, "Twelve artists, one weekend, every door open"),
                       b(.image, alt: "a studio door, open"), b(.cta, "openstudios.example", label: "Plan your visit")]]
        case .businesscard:
            blocks = [[b(.logo, "AM"), b(.headline, "Ada Moreno"), b(.subhead, "Studio lead"),
                       b(.details, items: ["Mail: ada@studio.example", "Phone: 555 0142", "Web: studio.example"])]]
        case .slide:
            blocks = [[b(.kicker, "Programme review"), b(.headline, "What the weekend showed"),
                       b(.list, items: ["visitors doubled on Sunday", "the print sale paid for the maps", "the reading room needs more seats"]),
                       b(.stat, "visitors over two days", figure: "3,400")]]
        case .banner:
            blocks = [[b(.kicker, "14 and 15 June"), b(.headline, "Open studios"), b(.subhead, "Twelve artists, one weekend"), b(.cta, label: "Plan your visit")]]
        }
        return Piece(title: "Open studios \(format.rawValue)", format: format, pages: blocks.map { PiecePage(blocks: $0) })
    }
}
