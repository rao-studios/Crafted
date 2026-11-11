#!/usr/bin/env swift
// WHAT: Render Crafted's app icon from a glyph SVG, in both appearances, embroidered as Craft's is: the glyph
//       stitched on a plate inside a ring of French knots that follows the tile's squircle. Dark: platinum on
//       graphite, the knots in white thread. Light: ink on Rao's paper, the knots in brass.
// IN:   --glyph <svg>  a 320-unit drawing with a viewBox, a <g id="glyph"> and a <g id="stitches"> group
//                      (default Design/glyph.svg). --out <dir> writes there instead of the app's places.
//       --stroke <n>   the line in the glyph's own units (default: the site's 8.4 px on a 1024 tile).
// OUT:  Without --out: Support/AppIcon/AppIcon.icon/Assets/icon_{dark,light}_1024.png (the layers macOS 26+ draws,
//       one per appearance, as icon.json names them), Support/AppIcon/icon_1024.png (the .icns fallback, via
//       make-iconset.sh: the light one), and Sources/CraftedApp/Resources/AppIcon-{dark,light}.png (the Dock tile a
//       bare dev binary sets for itself). With --out <dir>: <dir>/icon_{dark,light}_1024.png and
//       <dir>/AppIcon-{dark,light}.png.
// PIN:  A FORK OF CRAFT'S Scripts/art/gen-app-icon.swift: the same plate, ink, thread, knot ring and tile, so the two
//       apps sit together in the Dock. Only the drawing differs (and its group is `glyph`, not `hand`). Change the
//       shared numbers in both, and in the site's scripts/lib/embroidery.mjs.
// PIN:  The layers are left square and opaque. The system masks the icon to its own rounded shape; a pre-rounded PNG
//       would show two sets of corners. The dev tiles are the exception: an icon set in code is drawn as given, so
//       they carry the shape and its shadow.
// PIN:  The glyph draws at 1.7 units on a 320-unit box, a hairline at icon sizes. The icon strokes it at the site's
//       8.4 px on a 1024 tile instead, heavy enough to survive the Dock's 128 px.
//
//   swift Scripts/art/gen-app-icon.swift [--glyph Design/glyphs/needle-folder.svg] [--out build/icon] [--stroke 4.4]
//
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

/// The value after `flag` on the command line, if given.
func option(_ flag: String) -> String? {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}
func resolve(_ path: String) -> URL {
    path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)
}

let svgURL = resolve(option("--glyph") ?? "Design/glyph.svg")
let outDir = option("--out").map(resolve)
let size = 1024
/// The tile the Dock shows, in the PNG's pixels: the canvas over icon.json's 1.242, centred.
/// The dev tile draws the same square on Apple's 1024 grid, where the body is 824.
let tile = (origin: 100.0, side: 824.0, corner: 185.0)
/// The site's tile is 1024; this one is 824. Its numbers are scaled by this.
let site = tile.side / 1024

/// The embroidery, as the site gives it: knots on a squircle (n = 5) at 90% of the tile, about 26 px apart along
/// it and 6 px across the radius; the glyph 60% of the tile, centred, clear of them.
let ring = 0.9, knotSpacing = 26 * site, knotRadius = 6 * site, glyphShare = 0.6

let drawing = try String(contentsOf: svgURL, encoding: .utf8)
guard let start = drawing.range(of: "<g id=\"glyph\">"),
      let stitches = drawing.range(of: "<g id=\"stitches\">"),
      let end = drawing.range(of: "</g>", range: stitches.upperBound..<drawing.endIndex),
      let box = drawing.firstMatch(of: #/viewBox="(-?[\d.]+) (-?[\d.]+) ([\d.]+) ([\d.]+)"/#) else {
    fatalError("\(svgURL.lastPathComponent) needs a viewBox, a <g id=\"glyph\"> and a <g id=\"stitches\"> group")
}
let paths = String(drawing[start.lowerBound..<end.upperBound])
let (bx, by, bw) = (Double(box.1)!, Double(box.2)!, Double(box.3)!)
/// The glyph's share of the PNG, and its stroke in its own units: the site's 8.4 px on its tile, whatever the scale.
let art = glyphShare * tile.side / Double(size)
let stroke = option("--stroke").flatMap(Double.init) ?? 8.4 * bw / (1024 * glyphShare)

/// One appearance of the icon: its plate, the thread its knots are tied in, and its ink.
struct Variant {
    let name: String
    let plate: (top: String, bottom: String)
    /// A top light, gone by halfway down.
    let sheen: Double
    let thread: (colour: String, opacity: Double)
    /// Graded from the top left to the bottom right; one colour three times for an even ink.
    let ink: (tip: String, mid: String, wrist: String)
}

// Dark: graphite under a soft top light, white thread, and platinum graded across the drawing (the site's
// build-icon.mjs). Light: Rao's paper, brass thread and the drawing in one ink (the site's build-store-art.mjs).
let variants = [
    Variant(name: "dark", plate: ("#2e2e33", "#141416"), sheen: 0.10, thread: ("#f2f1ee", 1),
            ink: ("#f6f5f3", "#e5e4e2", "#bdbcb8")),
    Variant(name: "light", plate: ("#fffdf7", "#efebdf"), sheen: 0, thread: ("#ae9060", 0.75),
            ink: ("#37352f", "#37352f", "#37352f")),
]

/// The point at angle `t` on a superellipse of exponent `n` filling a `side` square.
func squircle(_ side: Double, _ t: Double, _ n: Double = 5) -> (x: Double, y: Double) {
    let r = side / 2, c = cos(t), s = sin(t)
    return (r + r * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n), r + r * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n))
}

/// Points around a `side` squircle, evenly spaced by length rather than angle (the angle crowds them into the
/// corners), about `spacing` apart and closing evenly: the site's `squircleAlong`.
func along(_ side: Double, _ spacing: Double, samples: Int = 4096) -> [(x: Double, y: Double)] {
    let points = (0...samples).map { squircle(side, Double($0) / Double(samples) * 2 * .pi) }
    var lengths = [0.0]
    for i in 1...samples { lengths.append(lengths[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)) }
    let total = lengths[samples]
    let count = Int((total / spacing).rounded())
    var out: [(x: Double, y: Double)] = []
    var j = 0
    for k in 0..<count {
        let d = Double(k) / Double(count) * total
        while lengths[j + 1] < d { j += 1 }
        let f = (d - lengths[j]) / (lengths[j + 1] - lengths[j])
        out.append((points[j].x + (points[j + 1].x - points[j].x) * f, points[j].y + (points[j + 1].y - points[j].y) * f))
    }
    return out
}

/// The knots, in the PNG's pixels: the ring centred on the tile.
let knots: [(x: Double, y: Double)] = {
    let side = tile.side * ring
    let offset = tile.origin + (tile.side - side) / 2
    return along(side, knotSpacing).map { ($0.x + offset, $0.y + offset) }
}()

func svg(_ variant: Variant) -> String {
    let circles = knots.map { String(format: "<circle cx=\"%.1f\" cy=\"%.1f\" r=\"%.2f\"/>", $0.x, $0.y, knotRadius) }.joined()
    let scale = Double(size) * art / bw
    let inset = Double(size) * (1 - art) / 2
    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="\(size)" height="\(size)" viewBox="0 0 \(size) \(size)">
      <defs>
        <linearGradient id="plate" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="\(variant.plate.top)"/>
          <stop offset="1" stop-color="\(variant.plate.bottom)"/>
        </linearGradient>
        <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#ffffff" stop-opacity="\(variant.sheen)"/>
          <stop offset="0.5" stop-color="#ffffff" stop-opacity="0"/>
        </linearGradient>
        <linearGradient id="ink" gradientUnits="userSpaceOnUse" x1="\(bx)" y1="\(by)" x2="\(bx + bw)" y2="\(by + bw)">
          <stop offset="0" stop-color="\(variant.ink.tip)"/>
          <stop offset="0.55" stop-color="\(variant.ink.mid)"/>
          <stop offset="1" stop-color="\(variant.ink.wrist)"/>
        </linearGradient>
      </defs>
      <rect width="\(size)" height="\(size)" fill="url(#plate)"/>
      <rect width="\(size)" height="\(size)" fill="url(#sheen)"/>
      <g fill="\(variant.thread.colour)" fill-opacity="\(variant.thread.opacity)">\(circles)</g>
      <g transform="translate(\(inset) \(inset)) scale(\(scale)) translate(\(-bx) \(-by))" fill="none" stroke="url(#ink)" stroke-width="\(stroke)" stroke-linecap="round" stroke-linejoin="round">
        \(paths)
      </g>
    </svg>
    """
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

/// The layer: opaque RGB, no alpha channel, as the system expects of a full-bleed square.
func layer(_ variant: Variant) -> CGImage {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("crafted-app-icon-\(UUID()).svg")
    try! svg(variant).write(to: tmp, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmp) }
    guard let image = NSImage(contentsOf: tmp) else { fatalError("could not load the \(variant.name) icon SVG") }
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fatalError("could not make a bitmap context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    guard let cgImage = context.makeImage() else { fatalError("could not render the \(variant.name) icon") }
    return cgImage
}

/// The dev tile: the layer cut to the tile's rounded square, over the shadow the Dock would give it.
/// The tile sits where it sits in the layer, so the layer draws unscaled. Written at half size: the
/// Dock's largest tile is 256 pt, 512 px.
func devTile(_ layer: CGImage) -> CGImage {
    let out = size / 2
    guard let context = CGContext(data: nil, width: out, height: out, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("could not make a bitmap context")
    }
    context.scaleBy(x: 0.5, y: 0.5)
    let body = CGRect(x: tile.origin, y: tile.origin, width: tile.side, height: tile.side)
    let shape = CGPath(roundedRect: body, cornerWidth: tile.corner, cornerHeight: tile.corner, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(shape)
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fillPath()
    context.restoreGState()
    context.addPath(shape)
    context.clip()
    context.draw(layer, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let cgImage = context.makeImage() else { fatalError("could not render the dev tile") }
    return cgImage
}

func write(_ image: CGImage, to url: URL) {
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("could not write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
    print("wrote \(url.path.replacingOccurrences(of: root.path + "/", with: ""))")
}

for variant in variants {
    let image = layer(variant)
    if let outDir {
        write(image, to: outDir.appendingPathComponent("icon_\(variant.name)_1024.png"))
        write(devTile(image), to: outDir.appendingPathComponent("AppIcon-\(variant.name).png"))
    } else {
        write(image, to: root.appendingPathComponent("Support/AppIcon/AppIcon.icon/Assets/icon_\(variant.name)_1024.png"))
        write(devTile(image), to: root.appendingPathComponent("Sources/CraftedApp/Resources/AppIcon-\(variant.name).png"))
        if variant.name == "light" { write(image, to: root.appendingPathComponent("Support/AppIcon/icon_1024.png")) }
    }
}
