import CraftedCore
@testable import CraftedForge
import Foundation
import XCTest

/// What code measures with no model: a palette from pixels, by area, in OKLab; a piece's ground and margins; the
/// folder's palette, lettered, with the designer's declared hexes taken exactly.
final class DesignerMeasureTests: XCTestCase {
    func testAPaletteIsQuantisedByAreaInOKLab() {
        let image = DesignerSupport.bands([("#F7F7F2", 0.5), ("#111111", 0.3), ("#E30613", 0.2)])
        let (pixels, w, h) = PieceRaster.rgba(image, side: 200)
        let clusters = PaletteQuantiser.clusters(PaletteQuantiser.points(rgba: pixels, count: w * h), k: 8)
        XCTAssertEqual(clusters.count, 3, "three flat colours are three clusters: \(clusters.map(\.hex))")
        let expected: [(String, Double)] = [("#F7F7F2", 0.5), ("#111111", 0.3), ("#E30613", 0.2)]
        for (cluster, (hex, share)) in zip(clusters, expected) {
            XCTAssertLessThan(cluster.lab.distance(OKLab(hex: hex)!), 0.01, "\(cluster.hex) is \(hex)")
            XCTAssertEqual(cluster.share, share, accuracy: 0.02, "largest first, by area")
        }
    }

    func testNearColoursMergeAndTheSamePicturesGiveTheSamePalette() {
        let image = DesignerSupport.bands([("#F7F7F2", 0.45), ("#F5F5F0", 0.15), ("#111111", 0.4)])
        let (pixels, w, h) = PieceRaster.rgba(image, side: 200)
        let points = PaletteQuantiser.points(rgba: pixels, count: w * h)
        let first = PaletteQuantiser.clusters(points, k: 8)
        XCTAssertEqual(first.count, 2, "two whites a step apart are one white")
        XCTAssertEqual(first.first?.share ?? 0, 0.6, accuracy: 0.02)
        XCTAssertEqual(PaletteQuantiser.clusters(points, k: 8), first, "deterministic: no random seeds")
    }

    func testAPieceIsMeasuredForGroundMarginsAndInk() {
        // A white page, a black block set 20% in from each side.
        let image = DesignerSupport.page("#FFFFFF", block: "#000000", inset: 0.2)
        let measure = PieceMeasure.measure(image)
        XCTAssertEqual(measure.ground, "light")
        XCTAssertEqual(measure.groundHex, "#FFFFFF")
        for side in 0..<4 { XCTAssertEqual(measure.margins[side], 0.2, accuracy: 0.02, "side \(side)") }
        XCTAssertEqual(measure.ink, 0.36, accuracy: 0.03)
        XCTAssertEqual(PieceMeasure.measure(DesignerSupport.page("#1A0F1F", block: "#C9A45C", inset: 0.3)).ground, "dark")
    }

    func testTheFixturesMeasureAsTheirDesignersMadeThem() throws {
        try DesignerSupport.requireFixtures()
        for name in ["swiss-mono", "velvet-night"] {
            let folder = DesignerSupport.fixture(name)
            let artefacts = try DesignerSupport.scratch()
            let inventory = try InventoryWalk.walk(source: folder, artefacts: artefacts, looks: 24)
            var measures: [String: PieceMeasure] = [:]
            for piece in inventory.distinct { measures[piece.id] = PieceMeasure.measure(PieceRaster.image(raster: artefacts.appendingPathComponent(piece.raster))!) }
            let fonts = inventory.fonts.flatMap { FontFact.read(folder.appendingPathComponent($0), path: $0, folder: folder) }
            let declared = DeclaredStyle.read(inventory.declared, folder: folder)
            let built = DesignMeasures.build(pieces: inventory.pieces, measures: measures, fonts: fonts, declared: declared, texts: [:])
            print("[\(name)] pieces: " + inventory.distinct.map(\.label).joined(separator: ", "))
            print("[\(name)] palette:\n" + built.paletteLines.joined(separator: "\n"))
            print("[\(name)] roles: \(built.roles) grounds: \(built.grounds) margins: \(built.margins)")
            print("[\(name)] declared faces: \(declared.faces.map { "\($0.family)/\($0.role ?? "-")" }) fonts: \(fonts.map { "\($0.family) \($0.openLicence ?? "closed")" })")
            print("[\(name)] marks: \(inventory.marks) unopenable: \(inventory.unopenable) corners: \(inventory.distinct.map { measures[$0.id]!.corners })")
            if name == "swiss-mono" {
                XCTAssertEqual(inventory.distinct.count, 4)
                XCTAssertEqual(inventory.marks, ["mark.svg"])
                XCTAssertTrue(built.palette.contains { $0.hex == "#E30613" && $0.source.contains("declared") }, "the declared red, exactly")
                XCTAssertEqual(built.roles["background"]?["light"], built.palette.first { $0.hex == "#F7F7F2" }?.id)
                XCTAssertEqual(fonts.first?.openLicence, "OFL-1.1", "Playfair's name table says OFL")
            } else {
                XCTAssertEqual(inventory.distinct.count, 4, "two pictures and a two-page PDF")
                XCTAssertEqual(inventory.unopenable, ["moodboard.sketch"])
                XCTAssertEqual(built.grounds["dark"], 4)
                XCTAssertTrue(declared.faces.contains { $0.family == "Velour Grotesk" }, "the CSS names a face the folder does not hold")
            }
        }
    }
}
