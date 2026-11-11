//  WHAT: The proof's pieces: one neutral piece per format, about no one in particular (an open-studio weekend), that a
//        style must draw clean. The built agent draws each from its spec with no model, so the proof sheet shows the
//        style, not a model's words, and shows exactly what the shipped kit draws.
//  OUT:  The proof gate (`perform` with {"spec": <one of these>, "format", "output"}); the README's proof sheet.
//  PIN:  NEUTRAL WORDS, NEVER THE DESIGNER'S. No sample piece of theirs is redrawn; these words belong to no one.

import Foundation

public enum ProofPieces {
    /// The piece for `format`, as the JSON the template's `spec` reads.
    public static func piece(_ format: String) -> [String: Any] {
        func b(_ kind: String, _ fields: [String: Any] = [:]) -> [String: Any] { fields.merging(["kind": kind]) { a, _ in a } }
        let details = b("details", ["items": ["Date: 14 and 15 June", "Time: 10 am to 6 pm", "Place: Canal Yard"]])
        let cta = b("cta", ["label": "Plan your visit", "text": "openstudios.example"])
        var pages: [[[String: Any]]]
        switch format {
        case "poster":
            pages = [[b("kicker", ["text": "Spring programme"]), b("headline", ["text": "Open studios"]),
                      b("subhead", ["text": "Twelve artists, one weekend, every door open"]), details, cta, b("footer", ["text": "Free entry. Step-free access."])]]
        case "flyer":
            pages = [[b("kicker", ["text": "Spring programme"]), b("headline", ["text": "Open studios"]),
                      b("lead", ["text": "Twelve artists open their doors for one weekend: see the work and meet the people who make it."]),
                      b("list", ["title": "Inside", "items": ["printmaking and letterpress", "ceramics", "a reading room"]]), details, cta]]
        case "brochure":
            pages = [[b("kicker", ["text": "Spring programme"]), b("headline", ["text": "Open studios"]), b("subhead", ["text": "A weekend guide"]),
                      b("image", ["alt": "the yard on opening day"]), b("footer", ["text": "Canal Yard, 14 and 15 June"])],
                     [b("headline", ["text": "How the weekend runs"]),
                      b("body", ["text": "Each studio keeps its own hours. The map at the gate shows who is open and what they are making."]),
                      b("steps", ["items": ["pick up a map at the gate", "follow the open doors", "sign the book on the way out"]]),
                      b("stat", ["figure": "12", "text": "studios open"]), details]]
        case "onepager":
            pages = [[b("kicker", ["text": "Spring programme"]), b("headline", ["text": "Open studios"]),
                      b("lead", ["text": "Twelve artists open their doors for one weekend."]),
                      b("body", ["text": "Each studio keeps its own hours. The map at the gate shows who is open and what they are making; the reading room stays open late on Saturday."]),
                      b("stat", ["figure": "12", "text": "studios"]), b("stat", ["figure": "9", "text": "years running"]),
                      b("callout", ["title": "Note", "text": "Bring cash for the print sale."]), details, b("footer", ["text": "Free entry."])]]
        case "socialcard":
            pages = [[b("kicker", ["text": "14 and 15 June"]), b("headline", ["text": "Open studios"]), b("subhead", ["text": "Twelve artists, one weekend"]),
                      b("cta", ["label": "Plan your visit"])]]
        case "story":
            pages = [[b("kicker", ["text": "14 and 15 June"]), b("headline", ["text": "Open studios"]), b("subhead", ["text": "Twelve artists, one weekend"]),
                      b("image", ["alt": "a studio door, open"]), cta]]
        case "businesscard":
            pages = [[b("logo", ["text": "AM"]), b("headline", ["text": "Ada Moreno"]), b("subhead", ["text": "Studio lead"]),
                      b("details", ["items": ["Web: studio.example", "Studio: Canal Yard 4"]])]]
        case "slide":
            pages = [[b("kicker", ["text": "Programme review"]), b("headline", ["text": "What the weekend showed"]),
                      b("list", ["items": ["visitors doubled on Sunday", "the print sale paid for the maps", "the reading room needs more seats"]]),
                      b("stat", ["figure": "3,400", "text": "visitors over two days"])]]
        default:
            pages = [[b("kicker", ["text": "14 and 15 June"]), b("headline", ["text": "Open studios"]), b("subhead", ["text": "Twelve artists, one weekend"]),
                      b("cta", ["label": "Plan your visit"])]]
        }
        return ["form": "crafted-piece/1", "title": "Open studios \(format)", "format": format, "pages": pages.map { ["blocks": $0] }]
    }

    /// The call the proof makes for `format`: the spec as a JSON string, the format, and where to write it.
    public static func input(_ format: String) throws -> Data {
        let spec = String(decoding: try JSONSerialization.data(withJSONObject: piece(format), options: [.sortedKeys]), as: UTF8.self)
        return try JSONSerialization.data(withJSONObject: ["spec": spec, "format": format, "output": "proof/\(format).png"], options: [.sortedKeys])
    }
}
