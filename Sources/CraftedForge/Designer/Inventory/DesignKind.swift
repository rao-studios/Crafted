import Foundation

/// What a file in a designer's folder is to the forge, by its extension.
public enum DesignKind: String, Codable, Sendable, CaseIterable {
    /// A picture of a piece: png, jpg, webp, heic, tiff, gif, a psd's composite.
    case raster
    /// A PDF, or an .ai saved PDF-compatible: each page a piece.
    case pdf
    /// A vector: a piece, or a mark when it is named as one; its colours and faces are declared.
    case svg
    case font
    /// CSS, Sass or Less: declared colours and faces.
    case css
    /// Design tokens as JSON.
    case tokens
    /// Words: a credit, an about, a licence beside a font.
    case text
    /// A file the forge cannot open: a Sketch, Figma, InDesign or Affinity file.
    case unopenable
    case other

    public static func of(_ url: URL) -> DesignKind {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "webp", "heic", "heif", "tif", "tiff", "gif", "bmp", "psd": return .raster
        case "pdf", "ai": return .pdf
        case "svg": return .svg
        case "ttf", "otf", "ttc", "otc", "woff", "woff2": return .font
        case "css", "scss", "sass", "less": return .css
        case "json": return .tokens
        case "txt", "md", "markdown", "rtf": return .text
        case "sketch", "fig", "indd", "idml", "afdesign", "afphoto", "afpub", "xd", "psb", "cdr", "eps", "key", "pages", "procreate", "kra", "xcf":
            return .unopenable
        default: return .other
        }
    }

    /// A file named as a mark rather than a piece: a logo, a monogram, a signature.
    public static func isMarkName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return ["mark", "logo", "monogram", "signature", "emblem", "wordmark"].contains { lower.contains($0) }
    }
}
