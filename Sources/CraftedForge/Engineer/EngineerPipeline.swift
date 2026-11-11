//  WHAT: An engineer's project into an agent: walk, cards, use cases, three interpretations, plan, port, gates.
//        See the plan's "Engineer framework".
//  TODO(engineer track): the pipeline. This stub refuses, so the flow says so instead of pretending.

import CraftedCore
import Foundation

public struct EngineerPipeline: RolePipeline {
    public init() {}
    public var role: CraftedRole { .engineer }
    public var stages: [ForgeStage] {
        [ForgeStage(id: "walk", title: "Walking the project", part: .analysis, weight: 1)]
    }
    public func generate(_ context: ForgeContext) async throws -> PipelineOutcome {
        throw ForgeError.stage("Engineer", "the engineer pipeline is not built yet")
    }
    public func assemble(_ request: AssemblyRequest) async throws -> AssembledPackage {
        throw ForgeError.stage("Engineer", "the engineer skeleton is not built yet")
    }
}
