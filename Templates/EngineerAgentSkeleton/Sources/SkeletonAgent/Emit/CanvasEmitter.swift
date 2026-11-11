import Foundation

/// Products as Canvas shows them: a report drawn as a PNG at 2x, or a paged PDF when it has pages; a series as its
/// `craft-timeseries/1` payload; everything else as output writes it.
enum CanvasEmitter {
    static func emit(_ products: [Product], into draft: inout EmitDraft) async throws {
        var renderer: ReportRenderer?
        for product in products {
            guard case .report(let report) = product.body else {
                OutputEmitter.emit(product, into: &draft)
                continue
            }
            if renderer == nil { renderer = await MainActor.run { ReportRenderer() } }
            guard let page = renderer else { continue }
            if report.isPaged {
                let pdf = try await page.pdf(report)
                draft.plan(report.name, suffix: ".pdf", data: pdf, kind: "report", what: "the report \(report.title) as a paged PDF")
            } else {
                let png = try await page.png(report)
                draft.plan(report.name, suffix: ".png", data: png, kind: "report", what: "the report \(report.title) as a picture")
            }
        }
    }
}
