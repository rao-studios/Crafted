import CraftedCore
import CraftedForge
import Foundation
import Granite
import GraniteAgents

extension ForgeService {
    /// Starts a run: a new generation for a dropped folder, an interrupted one resumed, or a finished one updated from
    /// its folder. The three share a shape: make a ForgeRun, keep it, consume its events into state, start it.
    ///
    /// PIN: ADOPTED BY ID. `reduce` takes the request only when nothing is live or starting; the effect goes on only
    /// when the committed state carries this request's id, so a refused start fails its ticket instead of running.
    public struct Start: GraniteReducer {
        public typealias Center = ForgeService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Request: Sendable {
                case new(folder: URL, role: CraftedRole)
                case resume(String)
                case update(String, folder: URL)
            }
            public var ticket: UUID
            public var id: UUID
            public var request: Request
            public var options: ForgeOptions
            public init(ticket: UUID, id: UUID, request: Request, options: ForgeOptions) {
                self.ticket = ticket; self.id = id; self.request = request; self.options = options
            }
        }

        @Payload public var meta: Meta?
        /// Below this service: the grid follows a run's records.
        @Relay var library: LibraryService

        public func reduce(state: inout Center.State) {
            guard let meta, !state.isBusy else { return }
            state.starting = meta.id
            state.problem = nil
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            guard state.starting == meta.id else {
                return .run { await ForgeService.tickets.fail(meta.ticket, ForgeServiceError.busy) }
            }
            let service = Live.service(ForgeService.self)
            let library = self.library
            guard let forge = ForgeService.forge else {
                return .run {
                    service.set(.startFailed(request: meta.id, ForgeServiceError.notConnected.localizedDescription))
                    await ForgeService.tickets.fail(meta.ticket, ForgeServiceError.notConnected)
                }
            }
            return .run {
                do {
                    let run: ForgeRun
                    switch meta.request {
                    case .new(let folder, let role): run = try await forge.start(folder: folder, role: role, options: meta.options)
                    case .resume(let id): run = try await forge.resume(id, options: meta.options)
                    case .update(let id, let folder): run = try await forge.update(id, from: folder, options: meta.options)
                    }
                    ForgeService.live.put(run.id, run)
                    service.set(.began(id: run.id, role: run.role))
                    library.refreshSoon()
                    let consumer = Task(priority: .userInitiated) {
                        await ForgeOps.consume(run, service: service, library: library)
                    }
                    if ForgeService.runs.register(run.id, consumer) {
                        await run.start()
                    } else {
                        consumer.cancel()
                        await run.cancel()
                    }
                    await ForgeService.tickets.resolve(meta.ticket, with: .started(run.id))
                } catch {
                    service.set(.startFailed(request: meta.id, error.localizedDescription))
                    library.refreshSoon()
                    await ForgeService.tickets.fail(meta.ticket, error)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
