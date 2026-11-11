//  WHAT: The watercolour's pictures, decoded once and kept: each scene's far, fog and near layers and arrival map,
//        the three blooms, and the glyph as a template image at a given stroke.
//  IN:   A scene and a layer, a bloom's tone, or a path under Resources/.
//  OUT:  A decoded CGImage (nil when the file is missing; views then draw paper alone), or the glyph's NSImage.
//  PIN:  ImageIO, not NSImage: WebP decodes through CGImageSource, and kCGImageSourceShouldCacheImmediately decodes now
//        rather than at first draw, so a cached picture never decodes twice. A scene is about 21 MB decoded; call
//        `preload` off the main thread before a page shows its painting.

import AppKit
import ImageIO

enum WatercolourArt {
    enum Layer: String, CaseIterable { case far, fog, near }

    private static let lock = NSLock()
    private static var images: [String: CGImage] = [:]
    /// Paths looked for and not found: not looked for again (a view asks every frame).
    private static var missing: Set<String> = []
    private static var glyphs: [Int: NSImage] = [:]

    static func layer(_ scene: WatercolourScene, _ layer: Layer) -> CGImage? {
        image("Watercolour/\(scene.rawValue)-\(layer.rawValue).webp")
    }

    /// The scene's arrival map: R when the wash arrives, G the wander the edge shimmers by.
    static func arrival(_ scene: WatercolourScene) -> CGImage? {
        image("washes/\(scene.rawValue)-arrival.png")
    }

    static func bloom(_ tone: BloomPool.Tone) -> CGImage? {
        image("Watercolour/bloom-\(tone.rawValue).webp")
    }

    /// Decodes a scene's pictures now, so its first frame does not. Safe from any thread.
    static func preload(_ scene: WatercolourScene) {
        for layer in Layer.allCases { _ = self.layer(scene, layer) }
        _ = arrival(scene)
        for tone in BloomPool.Tone.allCases { _ = bloom(tone) }
    }

    /// Whether a scene's three layers are decoded and kept.
    static func isDecoded(_ scene: WatercolourScene) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return Layer.allCases.allSatisfy { images["Watercolour/\(scene.rawValue)-\($0.rawValue).webp"] != nil }
    }

    static func image(_ path: String) -> CGImage? {
        lock.lock()
        if let cached = images[path] {
            lock.unlock()
            return cached
        }
        if missing.contains(path) {
            lock.unlock()
            return nil
        }
        lock.unlock()
        guard let url = WatercolourResources.url(path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else {
            lock.lock()
            missing.insert(path)
            lock.unlock()
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        if let raced = images[path] { return raced }
        images[path] = decoded
        return decoded
    }

    /// The glyph as a template image, its line redrawn at `stroke` units of its 320-unit box (glyph.svg draws at
    /// 1.7, a hairline below a few hundred points). Vector, so it is sharp at any size.
    static func glyph(stroke: Double) -> NSImage? {
        let key = Int((stroke * 10).rounded())
        lock.lock()
        defer { lock.unlock() }
        if let cached = glyphs[key] { return cached }
        guard let url = WatercolourResources.url("glyph.svg"), var svg = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        svg = svg.replacingOccurrences(of: #"stroke-width="1.7""#, with: "stroke-width=\"\(Double(key) / 10)\"")
        guard let image = NSImage(data: Data(svg.utf8)) else { return nil }
        image.isTemplate = true
        glyphs[key] = image
        return image
    }
}
