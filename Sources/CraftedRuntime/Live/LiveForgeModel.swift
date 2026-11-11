//  WHAT: The forge's model seam over the on-device runtime: the coder and the vision model, one resident at a time.
//  IN:   MLXModelRuntime (CraftedMLX), the only place Frigate is named.
//  OUT:  The Forge, when CRAFTED_MODELS is not `scripted` (CraftedRuntimeRoot.forgeModel).
//  PIN:  ROLES ARE MODELS. `coder` is Qwen3-Coder-Next, `vision` is Ministral 3; `prepare` swaps, letting the other go
//        first, and `release` frees whatever is resident so the weights really leave memory.
//  PIN:  NOT EXERCISED IN THIS PASS. The GPU is in use elsewhere; the app runs on ScriptedModel until the follow-up's
//        live suite (CRAFTED_MLX_LIVE=1).

import CraftedCore
import CraftedForge
import CraftedMLX
import Foundation

public struct LiveForgeModel: ForgeModel {
    let runtime: MLXModelRuntime

    public init(runtime: MLXModelRuntime = .shared) {
        self.runtime = runtime
    }

    public func resident() async -> ForgeModelRole? {
        switch await runtime.residentKind() {
        case .coder?: return .coder
        case .vision?: return .vision
        case nil: return nil
        }
    }

    public func prepare(_ role: ForgeModelRole) async throws {
        try await runtime.load(role.kind)
    }

    public func release() async {
        await runtime.unload()
    }

    public func text(_ role: ForgeModelRole, _ prompt: ModelPrompt, _ budget: ModelBudget) async throws -> ModelReply {
        let reply = try await runtime.text(role.kind, Self.ask(prompt, budget))
        return Self.reply(reply)
    }

    public func look(_ prompt: ModelPrompt, image: ModelImage, _ budget: ModelBudget) async throws -> ModelReply {
        let picture: RuntimePicture
        switch image {
        case .file(let url): picture = .file(url)
        case .png(let data): picture = .png(data)
        }
        return Self.reply(try await runtime.look(Self.ask(prompt, budget), picture: picture))
    }

    static func ask(_ prompt: ModelPrompt, _ budget: ModelBudget) -> RuntimeAsk {
        RuntimeAsk(system: prompt.system, user: prompt.user, maxTokens: budget.maxTokens, temperature: budget.temperature,
                   seed: budget.seed, seconds: budget.seconds)
    }

    static func reply(_ reply: RuntimeReply) -> ModelReply {
        let finish: ModelReply.Finish
        switch reply.finish {
        case .stop: finish = .stop
        case .length: finish = .length
        case .deadline: finish = .deadline
        }
        return ModelReply(text: reply.text, finish: finish, promptTokens: reply.promptTokens,
                          completionTokens: reply.completionTokens, seconds: reply.seconds)
    }
}
