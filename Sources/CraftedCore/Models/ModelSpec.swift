//  WHAT: One on-device model Crafted runs: its repository, the commit it is pinned to, how it loads, and what it
//        needs of the Mac.
//  OUT:  ModelCatalog (the two fixed specs), the model service, the Models page, the onboarding.

import Foundation

public enum ModelKind: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Reads design pieces: palettes, layout, type character. Ministral 3 8B.
    case vision
    /// Reads and writes code: the project walk, the port. Qwen3-Coder-Next.
    case coder

    public var id: String { rawValue }
}

public struct ModelSpec: Codable, Equatable, Sendable, Identifiable {
    /// Which factory loads it. PIN: always named, never guessed: Frigate's free `loadModelContainer` tries the
    /// VLM factory then the LLM one and swallows the first error, and MLXLLM also registers `mistral3` as text-only,
    /// so a failed vision load would come back as a model that ignores pictures.
    public enum Loader: String, Codable, Sendable { case llm, vlm }

    public var kind: ModelKind
    /// The Hugging Face repository, "org/name".
    public var id: String
    /// The commit downloads are pinned to.
    public var revision: String
    public var name: String
    public var publisher: String
    public var modelType: String
    public var loader: Loader
    public var downloadBytes: Int64
    public var fileCount: Int
    public var minimumMemoryGB: Int
    public var contextWindow: Int
    public var quantization: String
    public var license: String
    public var summary: String

    public init(kind: ModelKind, id: String, revision: String, name: String, publisher: String, modelType: String,
                loader: Loader, downloadBytes: Int64, fileCount: Int, minimumMemoryGB: Int, contextWindow: Int,
                quantization: String, license: String, summary: String) {
        self.kind = kind; self.id = id; self.revision = revision; self.name = name; self.publisher = publisher
        self.modelType = modelType; self.loader = loader; self.downloadBytes = downloadBytes; self.fileCount = fileCount
        self.minimumMemoryGB = minimumMemoryGB; self.contextWindow = contextWindow; self.quantization = quantization
        self.license = license; self.summary = summary
    }

    public var cardURL: URL { URL(string: "https://huggingface.co/\(id)")! }
    public var sizeGB: Double { Double(downloadBytes) / 1_000_000_000 }
    /// The folder name under the model home: "Qwen3-Coder-Next-REAP-48B-A3B-mlx-4bit".
    public var folderName: String { String(id.split(separator: "/").last ?? Substring(id)) }
    public var organisation: String { String(id.split(separator: "/").first ?? "") }
    public var shortRevision: String { String(revision.prefix(8)) }
}
