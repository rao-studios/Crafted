//  WHAT: Draws the designer fixtures' pieces: Fixtures/design/swiss-mono (four light pieces in a strict grid, one red)
//        and Fixtures/design/velvet-night (two dark pieces and a two-page PDF menu in gold on plum, one with a client's
//        "ACME CORP" logo in its corner). Everything else in those folders (tokens, styles, the font, the mark, the
//        words) is written by hand and kept as it is.
//  IN:   swift Fixtures/design/generate/generate.swift Fixtures/design
//  PIN:  DETERMINISTIC. No randomness, no dates: the same pieces every run, so a scripted look keyed on the measured
//        palette's letters keeps finding them.

import CoreGraphics
import CoreText
import Foundation
import ImageIO

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Fixtures/design")

func colour(_ hex: String) -> CGColor {
    let v = UInt32(hex.dropFirst(), radix: 16)!
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

/// A canvas with its origin at the top left, as a designer measures.
final class Canvas {
    let context: CGContext
    let width: CGFloat, height: CGFloat

    init(_ w: Int, _ h: Int, ground: String) {
        width = CGFloat(w); height = CGFloat(h)
        context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)
        fill(0, 0, width, height, ground)
    }

    init(pdf context: CGContext, width: CGFloat, height: CGFloat, ground: String) {
        self.context = context; self.width = width; self.height = height
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)
        fill(0, 0, width, height, ground)
    }

    func fill(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ hex: String) {
        context.setFillColor(colour(hex))
        context.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ hex: String) {
        context.setFillColor(colour(hex))
        context.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    func stroke(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ hex: String, width line: CGFloat) {
        context.setStrokeColor(colour(hex))
        context.setLineWidth(line)
        context.stroke(CGRect(x: x, y: y, width: w, height: h))
    }

    /// Lines of text, the first baseline `size` under `y`, each next `leading` × size down.
    func text(_ text: String, _ x: CGFloat, _ y: CGFloat, font: CTFont, _ hex: String, leading: CGFloat = 1.1, alignRight: Bool = false) {
        var baseline = y + CTFontGetAscent(font)
        for line in text.components(separatedBy: "\n") {
            let attributed = NSAttributedString(string: line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                                                                           NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour(hex)])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
            context.saveGState()
            context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            context.textPosition = CGPoint(x: alignRight ? x - CGFloat(width) : x, y: baseline)
            CTLineDraw(ctLine, context)
            context.restoreGState()
            baseline += CTFontGetSize(font) * leading
        }
    }

    func write(_ url: URL) {
        let image = context.makeImage()!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        print("wrote \(url.lastPathComponent)")
    }
}

func face(_ name: String, _ size: CGFloat) -> CTFont { CTFontCreateWithName(name as CFString, size, nil) }

/// The OFL face the swiss-mono folder carries, read from its own file.
func playfair(_ size: CGFloat) -> CTFont {
    let url = root.appendingPathComponent("swiss-mono/Fonts/PlayfairDisplay-Italic-VariableFont_wght.ttf")
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor], let first = descriptors.first else {
        return face("Georgia-Italic", size)
    }
    return CTFontCreateWithFontDescriptor(first, size, nil)
}

// MARK: swiss-mono: paper #F7F7F2, ink #111111, red #E30613, grey #6B6B6B.

let swiss = root.appendingPathComponent("swiss-mono")
let (paper, ink, red, grey) = ("#F7F7F2", "#111111", "#E30613", "#6B6B6B")
let bold = "HelveticaNeue-Bold", regular = "HelveticaNeue", medium = "HelveticaNeue-Medium"

do {
    let c = Canvas(1200, 1600, ground: paper)
    c.fill(90, 90, 320, 44, red)
    c.text("ZÜRICH LECTURES 2026", 90, 190, font: face(medium, 30), red)
    c.text("Form\nfollows\ngrid", 84, 260, font: face(bold, 210), ink, leading: 0.95)
    c.fill(90, 1000, 1020, 4, ink)
    let columns = ["Six evenings on the\ngrid, the measure and\nthe single red.", "Tuesdays at seven.\nHörsaal 3, ETH\nZentrum.", "Free entry.\nNo booking.\nBring a pencil."]
    for (i, text) in columns.enumerated() { c.text(text, 90 + CGFloat(i) * 345, 1040, font: face(regular, 30), grey, leading: 1.3) }
    c.text("1", 90, 1380, font: face(bold, 120), ink)
    c.text("six talks · one grid", 1110, 1470, font: face(regular, 28), grey, alignRight: true)
    c.write(swiss.appendingPathComponent("poster-form-follows-grid.png"))
}
do {
    let c = Canvas(850, 1100, ground: paper)
    c.circle(650, 230, 150, red)
    c.text("TYPE WORKSHOP", 70, 80, font: face(medium, 24), ink)
    c.text("Set it\nstraight", 66, 430, font: face(bold, 120), ink, leading: 0.95)
    c.text("a day with the grid", 70, 690, font: playfair(44), ink)
    c.fill(70, 780, 710, 3, ink)
    c.text("Date\n14 March", 70, 820, font: face(regular, 26), grey, leading: 1.3)
    c.text("Place\nStudio 4", 310, 820, font: face(regular, 26), grey, leading: 1.3)
    c.text("Price\n120 CHF", 550, 820, font: face(regular, 26), grey, leading: 1.3)
    c.text("Twelve places. Pencils provided.", 70, 1000, font: face(regular, 22), grey)
    c.write(swiss.appendingPathComponent("flyer-type-workshop.png"))
}
do {
    let c = Canvas(1080, 1080, ground: paper)
    c.text("01", 70, 40, font: face(bold, 460), red, leading: 0.9)
    c.text("Exhibition", 80, 600, font: face(bold, 110), ink)
    c.fill(80, 760, 920, 4, ink)
    c.text("Posters from the\nSwiss school, 1950–1970", 80, 800, font: face(regular, 40), grey, leading: 1.25)
    c.write(swiss.appendingPathComponent("card-exhibition-01.png"))
}
do {
    let c = Canvas(850, 1100, ground: paper)
    c.text("ANNUAL REPORT", 70, 80, font: face(medium, 24), ink)
    c.text("2025", 66, 150, font: face(bold, 170), ink)
    c.fill(0, 600, 850, 500, ink)
    c.fill(70, 600, 240, 14, red)
    c.text("What the grid\nheld this year", 70, 680, font: face(bold, 72), paper, leading: 1.0)
    c.text("in figures and in words", 70, 880, font: playfair(36), paper)
    c.write(swiss.appendingPathComponent("report-cover.png"))
}

// MARK: velvet-night: plum #1A0F1F, gold #C9A45C, cream #F3E9DA, rose #B04A6A.

let velvet = root.appendingPathComponent("velvet-night")
let (plum, gold, cream, rose) = ("#1A0F1F", "#C9A45C", "#F3E9DA", "#B04A6A")
let didot = "Didot-Bold", didotRegular = "Didot", didotItalic = "Didot-Italic"

do {
    let c = Canvas(1200, 1600, ground: plum)
    c.stroke(40, 40, 1120, 1520, rose, width: 3)
    c.text("THE WINTER GALA", 120, 150, font: face(didotRegular, 34), gold)
    c.text("A Night\nin Velvet", 110, 360, font: face(didot, 190), gold, leading: 0.95)
    c.fill(120, 820, 300, 2, gold)
    c.text("Dinner, a quartet\nand dancing until late", 120, 870, font: face(didotItalic, 52), cream, leading: 1.2)
    c.text("Saturday 13 December\nThe Orangery", 120, 1290, font: face(didotRegular, 40), cream, leading: 1.3)
    c.write(velvet.appendingPathComponent("gala-poster.png"))
}
do {
    let c = Canvas(1080, 1080, ground: plum)
    c.text("You are\ninvited", 90, 160, font: face(didot, 130), gold, leading: 0.95)
    c.fill(90, 480, 260, 2, rose)
    c.text("to the opening of the\nnew wine room", 90, 530, font: face(didotItalic, 48), cream, leading: 1.2)
    c.text("Friday 7 November, eight o'clock", 90, 760, font: face(didotRegular, 34), cream)
    // A client's logo, as a designer's export carries it: never the designer's own, never shipped.
    c.fill(770, 920, 270, 110, "#FFFFFF")
    c.text("ACME CORP", 792, 952, font: face(bold, 40), "#000000")
    c.write(velvet.appendingPathComponent("invite-acme.png"))
}
do {
    let url = velvet.appendingPathComponent("menu.pdf")
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    let pdf = CGContext(url as CFURL, mediaBox: &box, [kCGPDFContextTitle: "Menu", kCGPDFContextCreator: "generate.swift"] as CFDictionary)!
    let pages: [(String, [String])] = [
        ("Menu", ["Beetroot, smoked cream", "Duck, cherries, chard", "Dark chocolate, salt"]),
        ("Wine", ["Crémant, Loire", "Pinot noir, Baden", "Tawny port, ten years"]),
    ]
    for (title, items) in pages {
        pdf.beginPDFPage(nil)
        pdf.saveGState()
        let c = Canvas(pdf: pdf, width: 612, height: 792, ground: plum)
        c.stroke(24, 24, 564, 744, rose, width: 2)
        c.text(title, 70, 90, font: face(didot, 96), gold)
        c.fill(72, 230, 200, 1.5, gold)
        for (i, item) in items.enumerated() { c.text(item, 72, 280 + CGFloat(i) * 90, font: face(didotItalic, 30), cream) }
        c.text("The Orangery · Winter", 72, 700, font: face(didotRegular, 18), gold)
        pdf.restoreGState()
        pdf.endPDFPage()
    }
    pdf.closePDF()
    print("wrote menu.pdf")
}
