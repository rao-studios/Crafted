//  WHAT: A report drawn by WebKit with no window: one `WebPage`, a page loaded at a time, exported as a PNG at 2x or
//        as PDF pages joined into one document. Lifted from PlateAgent's Render/.
//  OUT:  CanvasEmitter.
//  PIN:  LAID OUT AT 1X, EXPORTED AT 2X BY ZOOM. A headless page has a scale of one and `snapshotWidth` does not
//        enlarge it, so the page is laid out as drawn and then zoomed to 2 for the export: WebKit sets the type again
//        at twice the size, so the PNG is sharp, not scaled up.
//  PIN:  NOTHING AT START. The page is made on the first report a call draws, on main, where WebKit lives.

import Foundation
import GraniteAgents
import ImageIO
import PDFKit
import WebKit

@MainActor
final class ReportRenderer {
    private let page = WebPage()

    func load(_ html: String) async throws {
        do {
            for try await event in page.load(html: html) where event == .finished { return }
        } catch {
            throw AgentRefusal(.host, "The report's page did not load in WebKit (\(error)): try again.")
        }
    }

    /// The report as one picture, 2x.
    func png(_ report: Report) async throws -> Data {
        try await load(ReportHTML.page(report, blocks: report.blocks.filter { $0 != .pageBreak }, first: true, paged: false))
        _ = try await page.callJavaScript("document.documentElement.style.zoom = '2'; return 1")
        let png: Data
        do {
            png = try await page.exported(as: .image(region: .contents))
        } catch {
            throw AgentRefusal(.host, "WebKit could not export the report as a picture (\(error)): try again.")
        }
        guard let source = CGImageSourceCreateWithData(png as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw AgentRefusal(.host, "WebKit's export of the report is not a picture: try again.")
        }
        return png
    }

    /// The report as a PDF, a page per page of blocks.
    func pdf(_ report: Report) async throws -> Data {
        let document = PDFDocument()
        for (index, blocks) in report.pages.enumerated() {
            try await load(ReportHTML.page(report, blocks: blocks, first: index == 0, paged: true))
            let data: Data
            do {
                data = try await page.exported(as: .pdf(region: .contents))
            } catch {
                throw AgentRefusal(.host, "WebKit could not export page \(index + 1) of the report (\(error)): try again.")
            }
            guard let one = PDFDocument(data: data) else { throw AgentRefusal(.host, "Page \(index + 1) of the report is not a PDF: try again.") }
            for at in 0..<one.pageCount {
                if let sheet = one.page(at: at) { document.insert(sheet, at: document.pageCount) }
            }
        }
        guard document.pageCount > 0, let data = document.dataRepresentation() else {
            throw AgentRefusal(.host, "The report made no PDF pages: try again.")
        }
        return data
    }
}
