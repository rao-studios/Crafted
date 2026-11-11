import CoreGraphics
import Foundation

/// A multi-page piece as one paged PDF: each page WebKit exported, drawn in order into a PDF context (vector, its
/// faces embedded), with the credit in the document's info (author, title, subject) and the spec in its XMP metadata,
/// so a PDF redraws as a PNG does.
///
/// PIN: COREGRAPHICS, NOT PDFKIT. PDFKit drops a document attribute it does not know (spike, 2026-11-11), so the spec
/// rides in XMP, which `CGContext.addDocumentMetadata` writes and the catalog's Metadata stream reads back.
public enum PiecePDF {
    public struct Info: Sendable {
        public var title: String
        public var author: String
        public var subject: String
        public var creator: String
        public var spec: String

        public init(title: String, author: String, subject: String, creator: String, spec: String) {
            self.title = title; self.author = author; self.subject = subject; self.creator = creator; self.spec = spec
        }
    }

    public static func merge(_ pages: [Data], info: Info) throws -> Data {
        let out = NSMutableData()
        guard let consumer = CGDataConsumer(data: out as CFMutableData) else { throw PieceError.render("no PDF consumer") }
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let auxiliary: [CFString: Any] = [kCGPDFContextTitle: info.title, kCGPDFContextAuthor: info.author,
                                          kCGPDFContextSubject: info.subject, kCGPDFContextCreator: info.creator]
        guard let context = CGContext(consumer: consumer, mediaBox: &box, auxiliary as CFDictionary) else { throw PieceError.render("no PDF context") }
        context.addDocumentMetadata(Data(xmp(info).utf8) as CFData)
        for data in pages {
            guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider) else { continue }
            for index in 1...max(document.numberOfPages, 1) {
                guard let page = document.page(at: index) else { continue }
                var media = page.getBoxRect(.mediaBox)
                context.beginPage(mediaBox: &media)
                context.drawPDFPage(page)
                context.endPage()
            }
        }
        context.closePDF()
        return out as Data
    }

    /// The spec a PDF carries in its XMP, if it carries one.
    public static func embedded(in data: Data) -> String? {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider), let catalog = document.catalog else { return nil }
        var stream: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(catalog, "Metadata", &stream), let stream else { return nil }
        var format = CGPDFDataFormat.raw
        guard let xml = CGPDFStreamCopyData(stream, &format) as Data? else { return nil }
        let text = String(decoding: xml, as: UTF8.self)
        guard let open = text.range(of: "<piece:spec>"), let close = text.range(of: "</piece:spec>", range: open.upperBound..<text.endIndex) else { return nil }
        return unescape(String(text[open.upperBound..<close.lowerBound]))
    }

    public static func pageCount(_ data: Data) -> Int {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider) else { return 0 }
        return document.numberOfPages
    }

    static func xmp(_ info: Info) -> String {
        """
        <?xpacket begin="\u{FEFF}" id="W5M0MpCehiHzreSzNTczkc9d"?><x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:piece="https://rao.nyc/ns/crafted-piece/1/"><dc:creator><rdf:Seq><rdf:li>\(escape(info.author))</rdf:li></rdf:Seq></dc:creator><dc:rights><rdf:Alt><rdf:li xml:lang="x-default">\(escape(info.subject))</rdf:li></rdf:Alt></dc:rights><piece:spec>\(escape(info.spec))</piece:spec></rdf:Description></rdf:RDF></x:xmpmeta><?xpacket end="w"?>
        """
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&amp;", with: "&")
    }
}
