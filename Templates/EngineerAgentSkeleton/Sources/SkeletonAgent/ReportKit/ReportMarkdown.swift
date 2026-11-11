import Foundation

/// A report as Markdown: what output writes, and what a hand-off carries as text.
enum ReportMarkdown {
    static func text(_ report: Report) -> String {
        var lines = ["# " + report.title]
        if let subtitle = report.subtitle { lines += ["", "_" + subtitle + "_"] }
        for block in report.blocks {
            lines.append("")
            switch block {
            case .heading(let text): lines.append("## " + text)
            case .paragraph(let text): lines.append(text)
            case .facts(let facts): lines += facts.map { "- **\($0.name)**: \($0.said)" }
            case .table(let columns, let rows):
                lines.append("| " + columns.map(cell).joined(separator: " | ") + " |")
                lines.append("|" + columns.map { _ in " --- |" }.joined())
                lines += rows.map { "| " + $0.map(cell).joined(separator: " | ") + " |" }
            case .list(let items): lines += items.map { "- " + $0 }
            case .bars(let title, let items):
                lines.append("**\(title)**")
                lines.append("")
                lines += items.map { "- \($0.label): \($0.shown ?? FactValue.format($0.value))" }
            case .note(let text): lines.append("> " + text)
            case .divider, .pageBreak: lines.append("---")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func cell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }
}
