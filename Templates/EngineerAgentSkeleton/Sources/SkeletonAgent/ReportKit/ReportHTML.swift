//  WHAT: A report, or one page of it, as a self-contained HTML page: the kit's one style, the system's faces, every
//        text escaped. WebKit lays it out (Render/).
//  PIN:  NOTHING FETCHED. The page loads no font, script or picture, so it draws the same on any Mac, offline.

import Foundation

enum ReportHTML {
    /// The width a picture is laid out at, in CSS pixels (exported at 2x).
    static let pictureWidth = 1080
    /// A PDF page, US Letter at 96 px to the inch.
    static let pageWidth = 816
    static let pageHeight = 1056

    static func page(_ report: Report, blocks: [ReportBlock], first: Bool, paged: Bool) -> String {
        var body = ""
        if first {
            body += "<header><h1>\(escape(report.title))</h1>"
            if let subtitle = report.subtitle { body += "<p class=\"subtitle\">\(escape(subtitle))</p>" }
            body += "</header>"
        }
        for block in blocks { body += html(block) }
        let width = paged ? pageWidth : pictureWidth
        let height = paged ? "min-height: \(pageHeight)px;" : ""
        return """
            <!doctype html><html><head><meta charset="utf-8"><style>
            :root { --ink: #1d1b18; --muted: #6b655c; --paper: #fdfbf4; --rule: #e4ddcf; --accent: #9a6b2f; }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body { background: var(--paper); }
            body { width: \(width)px; \(height) padding: 56px 64px; color: var(--ink);
                   font: 16px/1.5 -apple-system, "Helvetica Neue", sans-serif; }
            header { margin-bottom: 28px; border-bottom: 2px solid var(--ink); padding-bottom: 16px; }
            h1 { font: 600 34px/1.15 "New York", Georgia, serif; letter-spacing: -0.01em; }
            .subtitle { color: var(--muted); margin-top: 6px; font-size: 17px; }
            h2 { font: 600 21px/1.3 "New York", Georgia, serif; margin: 26px 0 10px; }
            p { margin: 0 0 12px; }
            .facts { display: flex; flex-wrap: wrap; gap: 12px; margin: 8px 0 18px; }
            .fact { border: 1px solid var(--rule); border-radius: 8px; padding: 10px 14px; min-width: 150px; background: #fff; }
            .fact .name { color: var(--muted); font-size: 13px; text-transform: uppercase; letter-spacing: 0.04em; }
            .fact .value { font-size: 22px; font-weight: 600; font-variant-numeric: tabular-nums; }
            table { border-collapse: collapse; width: 100%; margin: 6px 0 18px; font-variant-numeric: tabular-nums; }
            th { text-align: left; font-size: 13px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.04em;
                 border-bottom: 1px solid var(--ink); padding: 6px 10px; }
            td { border-bottom: 1px solid var(--rule); padding: 6px 10px; }
            ul { margin: 0 0 14px 22px; }
            .bars { margin: 8px 0 18px; }
            .bars .title { font-weight: 600; margin-bottom: 8px; }
            .bar { display: grid; grid-template-columns: 180px 1fr 90px; gap: 10px; align-items: center; margin: 4px 0; }
            .bar .track { background: var(--rule); border-radius: 4px; height: 14px; }
            .bar .fill { background: var(--accent); border-radius: 4px; height: 14px; }
            .bar .shown { text-align: right; font-variant-numeric: tabular-nums; }
            .note { border-left: 3px solid var(--accent); padding: 6px 12px; color: var(--muted); margin: 10px 0 16px; }
            hr { border: 0; border-top: 1px solid var(--rule); margin: 18px 0; }
            </style></head><body>\(body)</body></html>
            """
    }

    static func html(_ block: ReportBlock) -> String {
        switch block {
        case .heading(let text): return "<h2>\(escape(text))</h2>"
        case .paragraph(let text): return "<p>\(escape(text))</p>"
        case .facts(let facts):
            return "<div class=\"facts\">" + facts.map {
                "<div class=\"fact\"><div class=\"name\">\(escape($0.name))</div><div class=\"value\">\(escape($0.said))</div></div>"
            }.joined() + "</div>"
        case .table(let columns, let rows):
            let head = "<tr>" + columns.map { "<th>\(escape($0))</th>" }.joined() + "</tr>"
            let body = rows.map { "<tr>" + $0.map { "<td>\(escape($0))</td>" }.joined() + "</tr>" }.joined()
            return "<table>\(head)\(body)</table>"
        case .list(let items): return "<ul>" + items.map { "<li>\(escape($0))</li>" }.joined() + "</ul>"
        case .bars(let title, let items):
            let top = max(items.map { abs($0.value) }.max() ?? 0, .leastNonzeroMagnitude)
            return "<div class=\"bars\"><div class=\"title\">\(escape(title))</div>" + items.map { item in
                let share = Int((abs(item.value) / top * 100).rounded())
                return "<div class=\"bar\"><div>\(escape(item.label))</div><div class=\"track\"><div class=\"fill\" style=\"width: \(share)%\"></div></div>"
                    + "<div class=\"shown\">\(escape(item.shown ?? FactValue.format(item.value)))</div></div>"
            }.joined() + "</div>"
        case .note(let text): return "<div class=\"note\">\(escape(text))</div>"
        case .divider, .pageBreak: return "<hr>"
        }
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
