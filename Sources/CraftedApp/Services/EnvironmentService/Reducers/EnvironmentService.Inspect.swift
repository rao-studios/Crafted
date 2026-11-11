import CraftedCore
import Foundation
import Granite
import GraniteAgents

extension EnvironmentService {
    /// Counts what a proposed folder holds, off the main thread, for the confirmation card: every file the forge would
    /// see (build output and version control left out, as the forge leaves them out) and the pictures among them.
    struct Inspect: GraniteReducer {
        typealias Center = EnvironmentService.Center
        init() {}

        struct Meta: GranitePayload {
            var folder: URL
            init(folder: URL) { self.folder = folder }
        }

        @Payload var meta: Meta?

        func effect(state: Center.State) -> GraniteEffect {
            guard let meta, state.proposal?.folder == meta.folder else { return .none }
            let environment = Live.service(EnvironmentService.self)
            return .run {
                let counted = EnvironmentOps.count(meta.folder)
                environment.set(.counted(folder: meta.folder, files: counted.files, images: counted.images,
                                         capped: counted.capped, problem: counted.problem))
            }
        }

        var thread: DispatchQueue? { .main }
    }
}
