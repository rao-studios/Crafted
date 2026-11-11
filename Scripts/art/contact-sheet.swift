#!/usr/bin/env swift
// WHAT: One contact sheet of icon candidates: each candidate a row, both appearances, at 256, 64 and 32 px, cut to the
//       tile's rounded square as the Dock shows it, each on a ground of its own appearance.
// IN:   <dir>: one folder per candidate, each holding icon_light_1024.png and icon_dark_1024.png (gen-app-icon.swift
//       --out writes them). --reference <dir>: the same pair from another app (Craft's), drawn as the first row.
// OUT:  <sheet.png>.
// PIN:  What the Dock shows is the layer's middle 824 px (icon.json scales the layer by 1.242), so that is what is
//       cut and shrunk. Shrunk by halves, then once, so 32 px is a fair picture of 32 px.
//
//   swift Scripts/art/contact-sheet.swift build/icon-candidates build/icon-candidates/sheet.png [--reference <dir>]
//
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else { fatalError("usage: contact-sheet.swift <candidates dir> <sheet.png> [--reference <dir>]") }
let candidatesDir = URL(fileURLWithPath: args[1])
let sheetURL = URL(fileURLWithPath: args[2])
let referenceDir = args.firstIndex(of: "--reference").flatMap { $0 + 1 < args.count ? URL(fileURLWithPath: args[$0 + 1]) : nil }

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let tile = (origin: 100.0, side: 824.0, corner: 185.0)
let sizes = [256, 64, 32]
let pad = 24, labelWidth = 190, header = 44
let lightGround = CGColor(srgbRed: 0.93, green: 0.93, blue: 0.92, alpha: 1)
let darkGround = CGColor(srgbRed: 0.15, green: 0.15, blue: 0.16, alpha: 1)

func load(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func context(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    return c
}

/// The tile as the Dock shows it: the layer's body, its corners rounded.
func tileImage(_ layer: CGImage) -> CGImage {
    let side = Int(tile.side)
    let c = context(side, side)
    let body = CGRect(x: 0, y: 0, width: tile.side, height: tile.side)
    c.addPath(CGPath(roundedRect: body, cornerWidth: tile.corner, cornerHeight: tile.corner, transform: nil))
    c.clip()
    c.draw(layer, in: CGRect(x: -tile.origin, y: -tile.origin, width: Double(layer.width), height: Double(layer.height)))
    return c.makeImage()!
}

/// Shrunk by halves to within twice `px`, then once to `px`.
func shrink(_ image: CGImage, to px: Int) -> CGImage {
    var current = image
    while current.width / 2 >= px * 2 {
        let c = context(current.width / 2, current.height / 2)
        c.draw(current, in: CGRect(x: 0, y: 0, width: current.width / 2, height: current.height / 2))
        current = c.makeImage()!
    }
    let c = context(px, px)
    c.draw(current, in: CGRect(x: 0, y: 0, width: px, height: px))
    return c.makeImage()!
}

struct Row { let name: String; let light: CGImage; let dark: CGImage }

var rows: [Row] = []
func addRow(_ name: String, _ dir: URL) {
    guard let light = load(dir.appendingPathComponent("icon_light_1024.png")),
          let dark = load(dir.appendingPathComponent("icon_dark_1024.png")) else { return }
    rows.append(Row(name: name, light: tileImage(light), dark: tileImage(dark)))
}
if let referenceDir { addRow("craft (reference)", referenceDir) }
let names = ((try? FileManager.default.contentsOfDirectory(atPath: candidatesDir.path)) ?? []).sorted()
for name in names {
    var isFolder: ObjCBool = false
    let dir = candidatesDir.appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: dir.path, isDirectory: &isFolder), isFolder.boolValue { addRow(name, dir) }
}
guard !rows.isEmpty else { fatalError("no candidates in \(candidatesDir.path)") }

// Columns: the label, then for each size a light cell and a dark cell.
let cellWidths = sizes.flatMap { [$0 + pad * 2, $0 + pad * 2] }
let rowHeight = sizes.max()! + pad * 2
let width = labelWidth + cellWidths.reduce(0, +)
let height = header + rowHeight * rows.count
let sheet = context(width, height)
sheet.setFillColor(CGColor(gray: 1, alpha: 1))
sheet.fill(CGRect(x: 0, y: 0, width: width, height: height))

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
func text(_ s: String, at point: CGPoint, size: CGFloat, colour: NSColor = .black) {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: colour])
        .draw(at: point)
}
var x = labelWidth
for px in sizes {
    text("\(px) px", at: CGPoint(x: x + pad, y: height - header + 14), size: 15)
    x += (px + pad * 2) * 2
}
for (r, row) in rows.enumerated() {
    let top = height - header - rowHeight * (r + 1)
    text(row.name, at: CGPoint(x: 16, y: top + rowHeight / 2 - 9), size: 15)
    var x = labelWidth
    for px in sizes {
        for (image, ground) in [(row.light, lightGround), (row.dark, darkGround)] {
            let cell = CGRect(x: x, y: top, width: px + pad * 2, height: rowHeight)
            sheet.setFillColor(ground)
            sheet.fill(cell)
            let small = shrink(image, to: px)
            sheet.draw(small, in: CGRect(x: x + pad, y: top + (rowHeight - px) / 2, width: px, height: px))
            x += px + pad * 2
        }
    }
}
NSGraphicsContext.restoreGraphicsState()

try! FileManager.default.createDirectory(at: sheetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(sheetURL as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, sheet.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(sheetURL.path)") }
print("wrote \(sheetURL.path)")
