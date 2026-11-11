import Foundation
import ImageIO
import WebKit

/// A page in WebKit, with no window: one `WebPage`, a page loaded at a time. (After PlateAgent's PlateRenderer.)
///
/// PIN: MEASURED AT 1x, EXPORTED AT 2x BY ZOOM. A headless page has a 1024 × 768 viewport whatever the document says
/// (spikes, 2026-11-11). An image export of a `.rect` paints only what lies in that viewport, the rest blank; `.contents`
/// paints the whole document but is never smaller than the viewport. So the PNG is the page zoomed to 2 (WebKit lays
/// the type out again at twice the size: sharp, not scaled up), exported whole and cropped to exactly twice the page.
/// A PDF export of a `.rect` paints the whole rect, so the PDF names the page's own.
@MainActor
public final class PieceRenderer {
    private let page = WebPage()

    public init() {}

    func load(_ html: String) async throws {
        do {
            for try await event in page.load(html: html) where event == .finished { return }
        } catch {
            throw PieceError.render("the page did not load: \(error)")
        }
    }

    /// The page loaded, its type grown to fill it (up to `grow`) and fitted, measured, and exported: a PNG at 2x, and a
    /// PDF page when asked.
    public func draw(_ html: String, size: PieceSize, pdf: Bool, grow: Double = 1) async throws -> RenderedPage {
        try await load(html)
        _ = try await page.callJavaScript("return await window.__piece.grow(\(grow))")
        _ = try await page.callJavaScript("return await window.__piece.fit()")
        let json = try await page.callJavaScript("return window.__piece.measure()") as? String ?? "{}"
        let raw = PieceMeasure.raw(json)
        var pdfData: Data?
        if pdf {
            do {
                pdfData = try await page.exported(as: .pdf(region: .rect(CGRect(x: 0, y: 0, width: size.width, height: size.height))))
            } catch {
                throw PieceError.render("the PDF export failed: \(error)")
            }
        }
        let (width, height) = (Int(size.width * 2), Int(size.height * 2))
        var exported = Data()
        // PIN: AN EXPORT CAN BEAT THE ZOOM. Once in many pages the export came back at 1x (2026-11-11: 1080 × 1080 for a
        // 2160 × 2160 card), the zoom set but not yet laid out. So the zoom is set, the layout forced and given a beat,
        // the export's size checked, and the export taken again, longer after, when it is short.
        for attempt in 0..<3 {
            _ = try await page.callJavaScript("""
                document.documentElement.style.zoom = '2'; void document.documentElement.offsetHeight;
                await new Promise((r) => setTimeout(r, \(attempt == 0 ? 16 : 150))); return document.documentElement.scrollWidth
                """)
            do {
                exported = try await page.exported(as: .image(region: .contents))
            } catch {
                throw PieceError.render("the export failed: \(error)")
            }
            if let (w, h) = Self.pixels(exported), w >= width, h >= height { break }
        }
        let png = try Self.cropped(exported, width: width, height: height)
        return RenderedPage(png: png.data, pdf: pdfData, width: png.width, height: png.height, raw: raw)
    }

    static func pixels(_ data: Data) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = properties[kCGImagePropertyPixelWidth] as? Int, let h = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    /// The export cut to the page's top-left `width` × `height`: the viewport is larger than a small page.
    static func cropped(_ data: Data, width: Int, height: Int) throws -> (data: Data, width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PieceError.render("the export is not an image")
        }
        if image.width == width, image.height == height { return (data, width, height) }
        guard image.width >= width, image.height >= height,
              let cut = image.cropping(to: CGRect(x: 0, y: 0, width: width, height: height)) else {
            throw PieceError.render("the export is \(image.width)×\(image.height), smaller than the page's \(width)×\(height)")
        }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, "public.png" as CFString, 1, nil) else { throw PieceError.render("no PNG writer") }
        CGImageDestinationAddImage(destination, cut, nil)
        guard CGImageDestinationFinalize(destination) else { throw PieceError.render("the PNG did not write") }
        return (out as Data, width, height)
    }
}
