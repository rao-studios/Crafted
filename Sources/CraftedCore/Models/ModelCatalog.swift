//  WHAT: The two models Crafted runs, spelled once. The vision model reads a designer's pieces; the coder walks a
//        project and writes the port. Only one is resident at a time: vision work is batched before coder work.
//  PIN:  FIXED, AND EASY TO GROW. A third model, or a smaller coder for a smaller Mac, is one more spec here and a
//        case in `ModelKind`; nothing else names a repository.
//  PIN:  Pins and sizes from the Hub API (2026-11-10), the same commits Craft and Sewn pin, so a copy either app
//        downloaded is found on disk and never fetched twice (the model home is shared, ~/.rao/models).

import Foundation

public enum ModelCatalog {
    public static let vision = ModelSpec(
        kind: .vision,
        id: "rao-studios/Ministral-3-8B-Instruct-2512-mlx-8bit",
        revision: "3d71052d4c126d816a5a73df75222ecee8de3036",
        name: "Ministral 3 8B",
        publisher: "Mistral AI · Rao Studios mirror",
        modelType: "mistral3",
        loader: .vlm,
        downloadBytes: 10_410_000_000,
        fileCount: 16,
        minimumMemoryGB: 16,
        contextWindow: 262_144,
        quantization: "8-bit",
        license: "Apache-2.0",
        summary: "Reads a designer's pieces one at a time: layout, hierarchy, type character, colour roles, motifs. Pictures up to 1540 px."
    )

    public static let coder = ModelSpec(
        kind: .coder,
        id: "rao-studios/Qwen3-Coder-Next-REAP-48B-A3B-mlx-4bit",
        revision: "9664f44f273d250ab2fb4450b3310473f2371732",
        name: "Qwen3-Coder-Next 48B",
        publisher: "Qwen · Rao Studios mirror",
        modelType: "qwen3_next",
        loader: .llm,
        downloadBytes: 27_496_309_660,
        fileCount: 15,
        minimumMemoryGB: 48,
        contextWindow: 131_072,
        quantization: "4-bit",
        license: "Apache-2.0",
        summary: "Walks a whole project into use cases, offers three agents it could become, and ports the chosen one to Swift, compiling and testing as it goes."
    )

    /// Download order: the small one first, so the first card turns green early.
    public static let all: [ModelSpec] = [vision, coder]

    public static func spec(_ kind: ModelKind) -> ModelSpec {
        switch kind {
        case .vision: return vision
        case .coder: return coder
        }
    }

    public static var totalDownloadBytes: Int64 { all.reduce(0) { $0 + $1.downloadBytes } }
    /// The Mac this needs: the coder's floor.
    public static var minimumMemoryGB: Int { all.map(\.minimumMemoryGB).max() ?? 0 }
}
