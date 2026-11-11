import CraftedCore
import CraftedMLX
import Foundation
import Granite
import GraniteAgents

extension ModelService {
    /// Deletes a model's copy from the shared home, says what it freed, and reads the disk again. Never while that model
    /// downloads; the forge never has it resident here (the runtime holds nothing outside a run).
    public struct Remove: GraniteReducer {
        public typealias Center = ModelService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public var ticket: UUID
            public var kind: ModelKind
            public init(ticket: UUID, kind: ModelKind) { self.ticket = ticket; self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta, state.removing == nil, !state.isPending(meta.kind) else { return }
            state.removing = meta.kind
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            guard state.removing == meta.kind else {
                return .run { await ModelService.tickets.fail(meta.ticket, TicketError.refused("busy")) }
            }
            let models = Live.service(ModelService.self)
            let home = ModelService.home
            return .run {
                let spec = ModelCatalog.spec(meta.kind)
                do {
                    let freed = try ModelRemover.remove(spec, home: home)
                    models.set(.notice(String(format: "Removed %@ · freed %.1f GB", spec.name, Double(freed) / 1e9)))
                    let (statuses, fit) = ModelOps.read(home: home)
                    models.set(.read(statuses, fit))
                    models.set(.removing(nil))
                    await ModelService.tickets.resolve(meta.ticket, with: .removed(freed))
                } catch {
                    models.set(.problem("Could not remove \(spec.name): \(error.localizedDescription)"))
                    models.set(.removing(nil))
                    await ModelService.tickets.fail(meta.ticket, error)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
