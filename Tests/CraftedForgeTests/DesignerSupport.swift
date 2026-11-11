import CoreGraphics
import CraftedCore
@testable import CraftedForge
import Foundation
import XCTest

/// What the designer tests share: the repository's fixtures and templates, a scratch folder, and synthetic pictures.
enum DesignerSupport {
    static let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static func fixture(_ name: String) -> URL { repository.appendingPathComponent("Fixtures/design/\(name)", isDirectory: true) }
    static var scripts: URL { repository.appendingPathComponent("Fixtures/scripts", isDirectory: true) }

    /// Fixtures/ is kept off the public repository (.gitignore): a test that reads a fixture folder skips without it.
    static func requireFixtures() throws {
        guard FileManager.default.fileExists(atPath: repository.appendingPathComponent("Fixtures/design").path) else {
            throw XCTSkip("Fixtures/design is not in this checkout; it is kept off the public repository.")
        }
    }
    static var templates: TemplateSource { TemplateSource(root: repository.appendingPathComponent("Templates", isDirectory: true)) }

    static func scratch(_ name: String = "designer") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A picture of flat colour bands: each (hex, share of the width), left to right.
    static func bands(_ bands: [(String, Double)], width: Int = 200, height: Int = 100) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        var x = 0.0
        for (hex, share) in bands {
            let (r, g, b) = OKLab.rgb(hex)!
            context.setFillColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 1))
            let w = Double(width) * share
            context.fill(CGRect(x: x, y: 0, width: w, height: Double(height)))
            x += w
        }
        return context.makeImage()!
    }

    /// A page of `ground` with a block of `block` set `inset` (a share of each side) in from every edge.
    static func page(_ ground: String, block: String, inset: Double, width: Int = 200, height: Int = 200) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for (hex, rect) in [(ground, CGRect(x: 0, y: 0, width: width, height: height)),
                            (block, CGRect(x: Double(width) * inset, y: Double(height) * inset, width: Double(width) * (1 - 2 * inset), height: Double(height) * (1 - 2 * inset)))] {
            let (r, g, b) = OKLab.rgb(hex)!
            context.setFillColor(CGColor(srgbRed: r, green: g, blue: b, alpha: 1))
            context.fill(rect)
        }
        return context.makeImage()!
    }

    /// An observation of the fixed shape, every value unsure but the colours.
    static func look(background: String, ink: String, accent: [String] = [], ground: String = "light", marks: [Observation.Mark] = [],
                     notes: String? = nil) -> Observation {
        Observation(piece: .init(kind: "poster", confidence: "high"), ground: ground,
                    colourRoles: .init(background: background, ink: ink, accent: accent, secondary: [], muted: []),
                    layout: .init(structure: "hero", columns: 0, alignment: "left", margins: "generous", density: "balanced", symmetry: "asymmetric"),
                    hierarchy: .init(levels: 3, headline: .init(position: "top", scale: "huge", case: "sentence", treatment: "plain"), emphasis: "size"),
                    type: [.init(role: "display", class: "sans", sub: "neo-grotesque", weight: "bold", width: "normal", slant: "upright", tracking: "tight", contrast: "low")],
                    imagery: .init(kinds: ["none"], treatment: "none", share: "none"), motifs: [],
                    shape: .init(corners: "square", strokes: "regular", shadows: "none", fills: "flat"),
                    mood: ["bold"], marks: marks, people: "none", notes: notes)
    }
}
