//  WHAT: The look stage: the vision model shown each sampled piece, one per turn, with the measured palette's letters,
//        answering one Observation each, held to ObservationCheck. Each answer is cached by the piece's sha256, the
//        palette it was asked against and the prompt's version, in the shared cache's "looks".
//  PIN:  ONE RESIDENT. The vision model is made resident once, every piece looked at, before any coder ask.

import CraftedCore
import Foundation

public enum DesignLook {
    public static func run(_ context: ForgeContext, inventory: DesignInventory, measures: DesignMeasures) async throws -> [String: Observation] {
        let sample = inventory.sample
        guard !sample.isEmpty else { return [:] }
        let cache = context.cache.ledger("looks")
        let letters = Set(measures.palette.map(\.id))
        let system = try DesignerPrompts.system(.look)
        var looks: [String: Observation] = [:]
        var resident = false
        for (index, piece) in sample.enumerated() {
            try context.checkCancellation()
            context.progress("look", "Looking at \(piece.label)", fraction: Double(index) / Double(sample.count),
                             counts: ["looked": index, "pieces": sample.count])
            let key = "\(DesignerPrompts.Purpose.look.rawValue).\(DesignerPrompts.version)-\(piece.sha256)-\(measures.paletteKey)"
            if let kept = cache.get(Observation.self, key) {
                looks[piece.id] = kept
                continue
            }
            if !resident { try await context.use(.vision); resident = true }
            let prompt = ModelPrompt(purpose: DesignerPrompts.Purpose.look.rawValue, system: system, user: user(piece, measures: measures))
            let image = context.run.artefact(piece.raster)
            let look = try await context.ask.object(.vision, prompt, as: Observation.self, budget: .look, image: .file(image)) {
                ObservationCheck.problems($0, letters: letters)
            }
            try? cache.put(look, key)
            try context.run.write(look, "looks/\(piece.id).json")
            looks[piece.id] = look
        }
        return looks
    }

    /// What the model is told of one piece: its name, its size, and the palette by letter.
    static func user(_ piece: DesignInventory.Piece, measures: DesignMeasures) -> String {
        let measure = measures.pieces[piece.id]
        var lines = ["Piece: \(piece.label) (\(piece.width) × \(piece.height) px)."]
        if let measure { lines.append("Measured ground: \(measure.ground).") }
        lines.append("The palette, by letter:")
        lines += measures.paletteLines.map { "- " + $0 }
        lines.append("Say what you see in this piece, as the JSON object described.")
        return lines.joined(separator: "\n")
    }
}
