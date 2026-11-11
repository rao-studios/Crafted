//  WHAT: The inventory stage's work: walk the dropped folder, give every file a verdict, rasterise every piece (each
//        PDF page, each SVG that is not a mark) into the run's artefacts, collapse near-duplicates by difference hash,
//        and pick the sample the vision model looks at by farthest-point selection.
//  PIN:  NOTHING DROPPED SILENTLY. A file the forge cannot open is listed with "export as PDF or PNG"; a file with a
//        secret-shaped name is withheld and never read; anything else it does not use is "skipped".

import CoreGraphics
import CraftedCore
import Foundation

public enum InventoryWalk {
    /// The most files read, and the most pieces rasterised: a folder past these is sampled from what was read.
    static let fileLimit = 4_000
    static let pieceLimit = 240

    public static func walk(source: URL, artefacts: URL, looks: Int, note: (String, Int, Int) -> Void = { _, _, _ in }) throws -> DesignInventory {
        let fm = FileManager.default
        let base = source.standardizedFileURL.resolvingSymlinksInPath().path
        var paths: [String] = []
        if let walker = fm.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsPackageDescendants]) {
            for case let url as URL in walker {
                let path = url.standardizedFileURL.resolvingSymlinksInPath().path
                let relative = String(path.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !relative.isEmpty else { continue }
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let name = url.lastPathComponent
                if name.hasPrefix(".") || name == "__MACOSX" {
                    if isDirectory { walker.skipDescendants() }
                    continue
                }
                if !isDirectory { paths.append(relative) }
                if paths.count >= fileLimit { break }
            }
        }
        paths.sort()

        var inventory = DesignInventory(entries: [], pieces: [], sampled: [], fonts: [], declared: [], texts: [], marks: [], unopenable: [])
        let folder = artefacts.appendingPathComponent("pieces", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for (index, relative) in paths.enumerated() {
            let url = source.appendingPathComponent(relative)
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let kind = DesignKind.of(url)
            note(relative, index, paths.count)
            if let reason = SecretNames.reason(relative) {
                inventory.entries.append(.init(path: relative, kind: kind, bytes: bytes, verdict: "withheld: \(reason)"))
                continue
            }
            let name = url.lastPathComponent
            var verdict = "skipped"
            switch kind {
            case .raster where DesignKind.isMarkName(name), .svg where DesignKind.isMarkName(name):
                inventory.marks.append(relative)
                verdict = "mark"
                if kind == .svg { inventory.declared.append(relative) }
            case .raster:
                if inventory.pieces.count < pieceLimit, let image = PieceRaster.image(raster: url) {
                    try add(image, path: relative, page: nil, to: &inventory, folder: folder)
                    verdict = "piece"
                } else {
                    verdict = inventory.pieces.count >= pieceLimit ? "skipped: past \(pieceLimit) pieces" : "cannot open: export as PDF or PNG"
                    if verdict.hasPrefix("cannot") { inventory.unopenable.append(relative) }
                }
            case .svg:
                inventory.declared.append(relative)
                if inventory.pieces.count < pieceLimit, let image = PieceRaster.image(svg: url) {
                    try add(image, path: relative, page: nil, to: &inventory, folder: folder)
                    verdict = "piece"
                } else {
                    verdict = "declared"
                }
            case .pdf:
                let pages = PieceRaster.pageCount(pdf: url)
                if pages == 0 {
                    inventory.unopenable.append(relative)
                    verdict = "cannot open: export as PDF or PNG"
                } else {
                    var drawn = 0
                    for page in 1...min(pages, 64) where inventory.pieces.count < pieceLimit {
                        guard let image = PieceRaster.image(pdf: url, page: page) else { continue }
                        try add(image, path: relative, page: page, to: &inventory, folder: folder)
                        drawn += 1
                    }
                    verdict = drawn == 1 ? "piece" : "pieces: \(drawn) pages"
                }
            case .font:
                inventory.fonts.append(relative)
                verdict = "font"
            case .css:
                inventory.declared.append(relative)
                verdict = "declared"
            case .tokens:
                inventory.declared.append(relative)
                verdict = "declared"
            case .text:
                inventory.texts.append(relative)
                verdict = "words"
            case .unopenable:
                inventory.unopenable.append(relative)
                verdict = "cannot open: export as PDF or PNG"
            case .other:
                verdict = "skipped"
            }
            inventory.entries.append(.init(path: relative, kind: kind, bytes: bytes, verdict: verdict))
        }
        collapse(&inventory)
        inventory.sampled = sample(inventory.distinct, looks: looks).map(\.id)
        return inventory
    }

    /// One piece: written bounded as PNG under artefacts/pieces/<id>.png, hashed, its mean colour taken.
    static func add(_ image: CGImage, path: String, page: Int?, to inventory: inout DesignInventory, folder: URL) throws {
        guard let png = PieceRaster.png(image) else { return }
        let sha = ContentHash.sha256(png)
        let id = String(sha.prefix(12))
        let file = "pieces/\(id).png"
        let url = folder.appendingPathComponent("\(id).png")
        if !FileManager.default.fileExists(atPath: url.path) { try AtomicFile.write(png, to: url) }
        let (pixels, w, h) = PieceRaster.rgba(image, side: 16)
        var (l, a, b) = (0.0, 0.0, 0.0)
        for i in 0..<(w * h) {
            let lab = OKLab(r: Double(pixels[i * 4]) / 255, g: Double(pixels[i * 4 + 1]) / 255, b: Double(pixels[i * 4 + 2]) / 255)
            l += lab.l; a += lab.a; b += lab.b
        }
        let n = Double(max(w * h, 1))
        inventory.pieces.append(.init(id: id, path: path, page: page, raster: file, sha256: sha, width: image.width, height: image.height,
                                      hash: DifferenceHash.hash(image), mean: OKLab(l: l / n, a: a / n, b: b / n), duplicateOf: nil))
    }

    /// Marks each piece that repeats an earlier one (by path order) as its duplicate.
    static func collapse(_ inventory: inout DesignInventory) {
        for i in inventory.pieces.indices {
            for j in 0..<i where inventory.pieces[j].duplicateOf == nil {
                let (a, b) = (inventory.pieces[i], inventory.pieces[j])
                let sameShape = abs(Double(a.width) / Double(a.height) - Double(b.width) / Double(b.height)) < 0.03
                if a.sha256 == b.sha256 || (sameShape && DifferenceHash.distance(a.hash, b.hash) <= DifferenceHash.sameDesign && a.mean.distance(b.mean) < 0.03) {
                    inventory.pieces[i].duplicateOf = b.id
                    break
                }
            }
        }
    }

    /// Up to `looks` pieces spread across the folder: by structure (the hash) and colour (the mean).
    static func sample(_ pieces: [DesignInventory.Piece], looks: Int) -> [DesignInventory.Piece] {
        let count = min(max(looks, 1), 48)
        let picked = FarthestPoints.select(count, of: pieces.count) { i, j in
            Double(DifferenceHash.distance(pieces[i].hash, pieces[j].hash)) / 64 + pieces[i].mean.distance(pieces[j].mean) * 2
        }
        return picked.map { pieces[$0] }
    }
}
