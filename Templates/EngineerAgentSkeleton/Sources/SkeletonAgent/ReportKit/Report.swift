//  WHAT: A report a handler makes as data: a title, and blocks in order (headings, paragraphs, facts, tables, lists,
//        bars, notes, rules, page breaks). The kit lays it out, the same for every agent: a PNG for Canvas, or a paged
//        PDF when it has page breaks or asks for pages; Markdown when written as output.
//  PIN:  THE HANDLER SAYS, THE KIT PLACES. A handler never writes HTML or picks a font; a report reads the same from
//        any port, and its picture is the kit's.

import Foundation

public struct Report: Codable, Sendable, Equatable {
    /// The file's name, in words: "monthly totals" → monthly-totals.png.
    public var name: String
    public var title: String
    public var subtitle: String?
    public var blocks: [ReportBlock]
    /// A paged PDF instead of one picture; a page break starts a page.
    public var paged: Bool

    public init(name: String, title: String, subtitle: String? = nil, blocks: [ReportBlock] = [], paged: Bool = false) {
        self.name = name; self.title = title; self.subtitle = subtitle; self.blocks = blocks; self.paged = paged
    }

    /// Whether Canvas gets pages: asked for, or broken into them.
    public var isPaged: Bool { paged || blocks.contains(.pageBreak) }

    /// The blocks between page breaks.
    public var pages: [[ReportBlock]] {
        var pages: [[ReportBlock]] = [[]]
        for block in blocks {
            if block == .pageBreak { pages.append([]) } else { pages[pages.count - 1].append(block) }
        }
        return pages.filter { !$0.isEmpty }.isEmpty ? [[]] : pages.filter { !$0.isEmpty }
    }
}
