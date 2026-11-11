import Foundation

/// How a call's products are written: as files a person or a host reads (`output`), as what Canvas shows, pictures,
/// paged PDFs and series (`canvas`), or as one hand-off file for the next agent (`context`).
public enum Presentation: String, Codable, Sendable, CaseIterable {
    case output
    case canvas
    case context
}
