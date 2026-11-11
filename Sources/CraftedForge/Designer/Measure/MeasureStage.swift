//  WHAT: The measure stage: every distinct piece measured by code (palette, ground, margins, ink, corners, and its
//        words when OCR is on), each kept in the shared cache by its content; the folder's fonts read; what it declares
//        read; its words read for a credit; then the folder's measures built and written.
//  OUT:  artefacts/measures.json.

import CraftedCore
import Foundation

public enum MeasureStage {
    public static func run(_ context: ForgeContext, inventory: DesignInventory) throws -> DesignMeasures {
        let cache = context.cache.ledger("measures")
        let ocr = TextReader.enabled
        var measures: [String: PieceMeasure] = [:]
        let pieces = inventory.distinct
        for (index, piece) in pieces.enumerated() {
            try context.checkCancellation()
            context.progress("measure", "Measuring \(piece.label)", fraction: Double(index) / Double(max(pieces.count, 1)),
                             counts: ["measured": index, "pieces": pieces.count])
            let key = "\(PieceMeasure.version)-\(ocr ? "ocr" : "plain")-\(piece.sha256)"
            if let kept = cache.get(PieceMeasure.self, key) { measures[piece.id] = kept; continue }
            guard let image = PieceRaster.image(raster: context.run.artefact(piece.raster)) else { continue }
            var measure = PieceMeasure.measure(image)
            if ocr { measure.words = TextReader.lines(image) }
            try? cache.put(measure, key)
            measures[piece.id] = measure
        }
        let fonts = inventory.fonts.flatMap { FontFact.read(context.source.appendingPathComponent($0), path: $0, folder: context.source) }
        let declared = DeclaredStyle.read(inventory.declared, folder: context.source)
        var texts: [String: String] = [:]
        for file in inventory.texts {
            let url = context.source.appendingPathComponent(file)
            guard ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) <= 65_536,
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            texts[file] = PrivacyScan.redact(text, path: file)
        }
        let built = DesignMeasures.build(pieces: inventory.pieces, measures: measures, fonts: fonts, declared: declared, texts: texts)
        try context.run.write(built, "measures.json")
        return built
    }
}
