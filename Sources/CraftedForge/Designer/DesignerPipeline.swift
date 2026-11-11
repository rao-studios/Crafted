//  WHAT: A designer's folder into a style agent: inventory, measure, rights, look, synthesise, reconcile, proof,
//        assemble. See the plan's "Designer pipeline".
//  TODO(designer track): the pipeline. This stub refuses, so the flow says so instead of pretending.

import CraftedCore
import Foundation

public struct DesignerPipeline: RolePipeline {
    public init() {}
    public var role: CraftedRole { .designer }
    public var stages: [ForgeStage] {
        [ForgeStage(id: "inventory", title: "Reading your folder", part: .analysis, weight: 1)]
    }
    public func generate(_ context: ForgeContext) async throws -> PipelineOutcome {
        throw ForgeError.stage("Designer", "the designer pipeline is not built yet")
    }
    public func assemble(_ request: AssemblyRequest) async throws -> AssembledPackage {
        throw ForgeError.stage("Designer", "the designer template is not built yet")
    }
}
