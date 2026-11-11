import Foundation
import XCTest
@testable import SkeletonAgent

/// The report kit draws in WebKit: one picture at 2x, and a paged PDF with a page per page break. The only test that
/// touches WebKit, so it stays one.
final class RenderTests: XCTestCase {
    @MainActor
    func testAReportDrawsAsAPictureAndAsPages() async throws {
        let report = Report(name: "kit check", title: "A report", subtitle: "Drawn by the kit", blocks: [
            .facts([Fact("total", .number(57.5), unit: "USD")]),
            .table(columns: ["item", "amount"], rows: [["one", "1"], ["two", "2"]]),
            .bars(title: "Amounts", items: [ReportBar("one", 1), ReportBar("two", 2)]),
            .pageBreak,
            .paragraph("The second page."),
        ])
        let renderer = ReportRenderer()
        let png = try await renderer.png(report)
        XCTAssertEqual(Array(png.prefix(4)), [0x89, 0x50, 0x4E, 0x47], "a PNG")
        let pdf = try await renderer.pdf(report)
        XCTAssertEqual(String(decoding: pdf.prefix(5), as: UTF8.self), "%PDF-")
        XCTAssertTrue(report.isPaged)
        XCTAssertEqual(report.pages.count, 2)
    }
}
