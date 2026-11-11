//  WHAT: The words a style agent ships with, written from the style and the listing: the README ("Design by …", what
//        you can ask, the proof sheet, the style, credit and licences), the NOTICE (the style under CC BY 4.0 by
//        default, every face's licence, what never ships), and DesignerCredit.swift (the designer's name for the
//        agent's summary, guide and answers).
//  PIN:  PLACED, NEVER STAMPED. Each is written with the identity's real names and placed verbatim, so a designer whose
//        name holds a template token is never renamed by the assembler.

import CraftedCore
import Foundation

public enum DesignerDocuments {
    public static func readme(style: DesignerStyle, listing: AgentListing, identity: AgentIdentity, report: DesignerReport) -> String {
        let designer = style.credit.designer
        let credit = style.credit.url.map { "[\(designer)](\($0))" } ?? designer
        let roles = style.type.roles
        var text = """
        # \(identity.display)

        \(listing.tagline)

        **Design by \(credit).** \(style.name) is \(designer)'s design system, made a [Craft](https://craft.rao.nyc) agent: ask `$\(identity.word)` \
        for a poster, flyer, brochure, one-pager, social card, story, business card, slide or banner, and it is drawn in this style. Every piece \
        carries a colophon crediting \(designer).

        """
        if report.proof {
            text += "\n![Every format drawn in \(style.name) by the agent itself](Assets/proof.png)\n"
        }
        text += """

        ## What you can ask

        ```
        $\(identity.word) a poster for the spring open studios, 14 and 15 June at Canal Yard
        $\(identity.word) a two-page brochure about the reading room
        $\(identity.word) a social card announcing the print sale, dark
        $\(identity.word) a business card for Ada Moreno, studio lead
        ```

        Craft's model writes the piece as blocks of words (a headline, a kicker, a lead, lists, figures, details, a call to action); \
        the agent's kit sets them in \(style.name): its colours, faces, spacing, layouts and motifs. It measures the page, sets the type \
        smaller where it must, and has the model cut what still does not fit. Your own words, given in `content`, are set as you wrote \
        them; nothing you did not say is made up.

        | Format | Page | Drawn as |
        |---|---|---|
        | poster | 1200 × 1600 | PNG at 2x |
        | flyer, one-pager | 850 × 1100 | PNG at 2x |
        | brochure | 850 × 1100 a page | paged PDF |
        | social card | 1080 × 1080 | PNG at 2x |
        | story | 1080 × 1920 | PNG at 2x |
        | business card | 1050 × 600 | PNG at 2x |
        | slide | 1920 × 1080 | PNG, or a paged PDF for a deck |
        | banner | 1500 × 500 | PNG at 2x |

        Each file carries the piece it was drawn from: call again with `spec` set to it, and a `brief` saying what to change.

        ## The style

        - **Colour.** \(style.colour.palette.filter { ($0.weight ?? 0) > 0 || $0.source?.contains("declared") == true }.prefix(6).map { "\($0.name ?? $0.id) `\($0.hex)`" }.joined(separator: ", ")).
        - **Type.** Display in \(roles["display"]?.family ?? "a sans"), body in \(roles["body"]?.family ?? "a sans")\(roles["heading"].map { ", headings in \($0.family)" } ?? "").
        - **Layout.** \(style.layout.alignment == "centre" ? "Centred" : style.layout.alignment == "right" ? "Set right" : "Set left"), \(style.space.density), \
        margins of \(Int((style.space.pageMargin * 100).rounded()))% of the page; drawn with \(Set(style.layout.archetypes.map(\.engine)).sorted().joined(separator: ", ")) layouts.

        """
        if !report.verification.isEmpty {
            text += "\n## How it was checked\n\n" + report.verification.map { "- " + $0 }.joined(separator: "\n") + "\n"
        }
        text += """

        ## Credit and licence

        - The code is under the \(listing.license.rawValue) licence (`LICENSE`).
        - The style (`Sources/\(identity.kitTarget)/Resources/Style`) is \(designer)'s, under \(licenceName(style.credit.styleLicence)): \
        share pieces and keep the credit, "\(style.name) by \(designer)". Faces and their licences are listed in `NOTICE`.
        - Nothing in this package is a sample of \(designer)'s work, a photograph or a client's logo: only the style, the faces it may \
        ship\(style.mark != nil ? ", and \(designer)'s own mark" : "").

        ## Requirements

        macOS 26 (WebKit draws each piece in-process), and Swift 6 to build. Made with Crafted.

        """
        return text
    }

    public static func notice(style: DesignerStyle, rights: RightsOutcome, identity: AgentIdentity, listing: AgentListing) -> String {
        let designer = style.credit.designer
        var lines = [
            identity.display, "",
            "The code of this package is under the \(listing.license.rawValue) licence: see LICENSE.", "",
            "THE STYLE",
            "The style in Sources/\(identity.kitTarget)/Resources/Style (style.json\(style.mark != nil ? " and the mark in Marks/" : "")) is \(designer)'s",
            "design system \"\(style.name)\", licensed under \(licenceName(style.credit.styleLicence)): \(licenceURL(style.credit.styleLicence))",
            "Credit it as \"\(style.name) by \(designer)\"\(style.credit.url.map { " (\($0))" } ?? "").", "",
            "FONTS",
        ]
        for family in style.type.families {
            if family.bundled {
                lines.append("\(family.family): \(family.licence == "attested" ? "the designer attests they may publish it" : family.licence ?? "open"), "
                             + "bundled in Sources/\(identity.kitTarget)/Resources/Style/\(family.files.first.map { ($0 as NSString).deletingLastPathComponent } ?? "Fonts")/.")
            } else {
                lines.append("\(family.family): a macOS system face, not bundled.")
            }
        }
        for font in rights.fonts where font.decision == "substitute" {
            lines.append("\(font.family): named by the designer and not bundled; a system face of its class stands in.")
        }
        let declaredMissing = style.provenance.decisions.filter { $0.contains("cannot ship") }
        lines += declaredMissing
        lines += ["The kit's own tests carry Playfair Display Italic under the SIL Open Font License 1.1",
                  "(Tests/\(identity.kitTarget)Tests/Fixtures/Styles/ink-press/Fonts/OFL.txt).", "",
                  "WHAT NEVER SHIPS",
                  "No sample of the designer's work, no photograph and no client's logo is in this package."]
        return lines.joined(separator: "\n") + "\n"
    }

    public static func credit(style: DesignerStyle) -> String {
        """
        //  WHAT: Who this agent's style belongs to, as its summary, its guide and every answer say it. Crafted writes this file
        //        from the designer's credit when it makes the agent; style.json carries the same for the colophon.
        //  PIN:  NAMES ARE THE DESIGNER'S. This file is placed as it is, never stamped, so a name is never renamed.

        enum DesignerCredit {
            static let designer = \(SwiftLiteral.string(style.credit.designer))
            static let url: String? = \(SwiftLiteral.optional(style.credit.url))
            static let style = \(SwiftLiteral.string(style.name))
            static let licence = \(SwiftLiteral.string(licenceName(style.credit.styleLicence)))
        }

        """
    }

    static func licenceName(_ id: String) -> String {
        id == "CC-BY-4.0" ? "CC BY 4.0" : id.replacingOccurrences(of: "-", with: " ")
    }

    static func licenceURL(_ id: String) -> String {
        id == "CC-BY-4.0" ? "https://creativecommons.org/licenses/by/4.0/" : "see the designer's terms"
    }
}
