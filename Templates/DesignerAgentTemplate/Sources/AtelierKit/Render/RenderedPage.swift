import Foundation

/// A page as WebKit drew it: the PNG at 2x, its PDF page when asked, its size in pixels, and what the measure found.
public struct RenderedPage: Sendable {
    public let png: Data
    public let pdf: Data?
    public let width: Int
    public let height: Int
    public let raw: PieceMeasure.Raw
}
