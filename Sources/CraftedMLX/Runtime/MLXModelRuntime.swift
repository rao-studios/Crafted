//  WHAT: The one-resident model runtime: loads either of Crafted's two models from the shared home, asks it in text or
//        with one picture, and lets it go so its memory really returns to the Mac.
//  IN:   ModelCatalog's specs; ModelLocator (a complete copy on disk); MemoryPlan (the GPU limits).
//  OUT:  LiveForgeModel (CraftedRuntime), the forge's model seam over it.
//  PIN:  ONE RESIDENT. Loading one model unloads the other first; the forge batches every picture before any coder call,
//        so a designer run swaps once and an engineer run never.
//  PIN:  THE FACTORY IS NAMED, NEVER GUESSED. `VLMModelFactory.shared.loadContainer` for the vision model and
//        `LLMModelFactory.shared.loadContainer` for the coder: Frigate's free `loadModelContainer` tries VLM then LLM
//        and swallows the first error, and MLXLLM registers `mistral3` as text-only, so a failed vision load would come
//        back as a model that ignores pictures.
//  PIN:  `Processing(resize: nil)`. ChatSession's default shrinks every picture to 512×512; the picture is bounded to
//        1540 px by PictureBounds instead, and Mistral 3 takes one picture per turn.
//  PIN:  UNLOAD FREES. Dropping the container only moves its weights into MLX's buffer cache; `unload` drops it, bumps
//        the epoch (an ask that began before it fails rather than run on a model that is gone) and clears the cache.
//  PIN:  HELD ACTIVITY. Every load and every ask holds a `.userInitiated` activity (GenerationActivity): backgrounded,
//        generation fell from ~22 to 0.4 tok/s.
//  PIN:  NEVER LOADED IN THIS PASS. The GPU is in use elsewhere; the app and its self-test run on ScriptedModel
//        (CRAFTED_MODELS=scripted). This compiles and is exercised in the follow-up (CRAFTED_MLX_LIVE=1).

import CoreImage
import CraftedCore
import Foundation
import FrigateBridge
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM

/// One ask, as the runtime takes it: no MLX types cross this boundary.
public struct RuntimeAsk: Sendable, Equatable {
    public var system: String
    public var user: String
    public var maxTokens: Int
    public var temperature: Double
    public var seed: UInt64?
    /// A deadline for the whole ask; generation stops at it and the reply says `deadline`.
    public var seconds: Double?

    public init(system: String, user: String, maxTokens: Int, temperature: Double, seed: UInt64? = nil, seconds: Double? = nil) {
        self.system = system; self.user = user; self.maxTokens = maxTokens; self.temperature = temperature
        self.seed = seed; self.seconds = seconds
    }
}

public enum RuntimePicture: Sendable, Equatable {
    case file(URL)
    case png(Data)
}

public struct RuntimeReply: Sendable, Equatable {
    public enum Finish: String, Sendable { case stop, length, deadline }

    public var text: String
    public var finish: Finish
    public var promptTokens: Int
    public var completionTokens: Int
    public var seconds: Double

    public init(text: String, finish: Finish, promptTokens: Int, completionTokens: Int, seconds: Double) {
        self.text = text; self.finish = finish; self.promptTokens = promptTokens
        self.completionTokens = completionTokens; self.seconds = seconds
    }
}

public enum MLXRuntimeError: Error, LocalizedError, Equatable {
    case notInstalled(String)
    case notVision(String)
    case released

    public var errorDescription: String? {
        switch self {
        case .notInstalled(let name): return "\(name) is not on this Mac. Download it in Settings › Models."
        case .notVision(let name): return "\(name) cannot read pictures."
        case .released: return "The model was let go while it was answering."
        }
    }
}

public actor MLXModelRuntime {
    public static let shared = MLXModelRuntime()

    private let home: ModelHome
    private let plan: MemoryPlan
    private var resident: (kind: ModelKind, container: ModelContainer)?
    private var loading: (kind: ModelKind, task: Task<ModelContainer, Error>)?
    /// Bumped by every unload: an ask that started under an older epoch is refused when it resumes.
    private var epoch = 0

    public init(home: ModelHome = .standard, plan: MemoryPlan = .read()) {
        self.home = home
        self.plan = plan
    }

    /// The model in memory now, if any.
    public func residentKind() -> ModelKind? { resident?.kind ?? loading?.kind }

    /// Makes `kind` resident, letting the other go first. Slow the first time: tens of seconds for the coder.
    public func load(_ kind: ModelKind) async throws {
        _ = try await container(kind)
    }

    /// Lets the resident model go and gives its memory back to the Mac.
    public func unload() {
        guard resident != nil || loading != nil else { return }
        loading?.task.cancel()
        loading = nil
        resident = nil
        epoch += 1
        MLX.Memory.clearCache()
    }

    /// A text answer from `kind` (the coder, or the vision model without a picture).
    public func text(_ kind: ModelKind, _ ask: RuntimeAsk) async throws -> RuntimeReply {
        try await GenerationActivity.held {
            let container = try await container(kind)
            return try await generate(container, ask, pictures: [])
        }
    }

    /// The vision model's answer about one picture.
    public func look(_ ask: RuntimeAsk, picture: RuntimePicture) async throws -> RuntimeReply {
        let spec = ModelCatalog.vision
        guard spec.loader == .vlm else { throw MLXRuntimeError.notVision(spec.name) }
        return try await GenerationActivity.held {
            let image: CIImage
            switch picture {
            case .file(let url): image = try PictureBounds.bounded(file: url)
            case .png(let data): image = try PictureBounds.bounded(data: data)
            }
            let container = try await container(.vision)
            return try await generate(container, ask, pictures: [.ciImage(image)])
        }
    }

    // MARK: - The slot

    private func container(_ kind: ModelKind) async throws -> ModelContainer {
        if let resident, resident.kind == kind { return resident.container }
        if let loading, loading.kind == kind { return try await loading.task.value }
        // The other model goes first: two are never resident together.
        if resident != nil || loading != nil { unload() }

        let spec = ModelCatalog.spec(kind)
        guard let located = ModelLocator.locate(spec, home: home) else { throw MLXRuntimeError.notInstalled(spec.name) }
        let limits = plan.limits(for: spec)
        try MLXStack.configureMemory(cacheLimitMB: limits.cacheMB, memoryLimitMB: limits.memoryMB)
        // The real folder, not a link to it: Frigate's loader enumerates the folder it is handed, and the enumerator
        // does not descend into a symlinked root.
        let directory = located.path.resolvingSymlinksInPath()
        let loader = spec.loader
        let task = Task<ModelContainer, Error> {
            try await GenerationActivity.held {
                switch loader {
                case .vlm: return try await VLMModelFactory.shared.loadContainer(from: directory, using: HubTokenizerLoader())
                case .llm: return try await LLMModelFactory.shared.loadContainer(from: directory, using: HubTokenizerLoader())
                }
            }
        }
        loading = (kind, task)
        do {
            let container = try await task.value
            guard loading?.kind == kind else { throw MLXRuntimeError.released }
            loading = nil
            resident = (kind, container)
            return container
        } catch {
            if loading?.kind == kind { loading = nil }
            MLX.Memory.clearCache()
            throw error
        }
    }

    // MARK: - Generation

    /// One fresh conversation per ask: one answer must not colour the next.
    private func generate(_ container: ModelContainer, _ ask: RuntimeAsk, pictures: [UserInput.Image]) async throws -> RuntimeReply {
        let began = epoch
        let parameters = GenerateParameters(maxTokens: ask.maxTokens, temperature: Float(ask.temperature), seed: ask.seed)
        let session = ChatSession(container, instructions: ask.system.isEmpty ? nil : ask.system,
                                  generateParameters: parameters, processing: UserInput.Processing(resize: nil))
        let started = Date()
        var text = ""
        var info: GenerateCompletionInfo?
        var finish = RuntimeReply.Finish.stop
        for try await item in session.streamDetails(to: ask.user, images: pictures) {
            try Task.checkCancellation()
            guard epoch == began else { throw MLXRuntimeError.released }
            switch item {
            case .chunk(let chunk): text += chunk
            case .info(let completion): info = completion
            case .toolCall: break
            }
            if let seconds = ask.seconds, Date().timeIntervalSince(started) > seconds {
                finish = .deadline
                break
            }
        }
        if finish != .deadline, let info, case .length = info.stopReason { finish = .length }
        return RuntimeReply(text: text, finish: finish, promptTokens: info?.promptTokenCount ?? 0,
                            completionTokens: info?.generationTokenCount ?? 0, seconds: Date().timeIntervalSince(started))
    }
}
