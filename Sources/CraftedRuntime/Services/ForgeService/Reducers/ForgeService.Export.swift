import CraftedCore
import CraftedForge
import Foundation
import Granite
import GraniteAgents

extension ForgeService {
    /// Download: the generation assembled again with its saved listing and icon, its gates run, and zipped to the
    /// archive the person chose. Never while that generation's run is live; one download at a time.
    public struct Export: GraniteReducer {
        public typealias Center = ForgeService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public var ticket: UUID
            public var request: UUID
            public var id: String
            public var archive: URL
            public var options: ForgeOptions
            public init(ticket: UUID, request: UUID, id: String, archive: URL, options: ForgeOptions) {
                self.ticket = ticket; self.request = request; self.id = id; self.archive = archive; self.options = options
            }
        }

        @Payload public var meta: Meta?
        /// Below this service: the tile's "last download" follows.
        @Relay var library: LibraryService

        public func reduce(state: inout Center.State) {
            guard let meta, state.exporting == nil, state.live(meta.id)?.phase.isLive != true else { return }
            state.exporting = meta.id
            state.exportRequest = meta.request
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            guard state.exportRequest == meta.request else {
                return .run { await ForgeService.tickets.fail(meta.ticket, ForgeServiceError.busy) }
            }
            let service = Live.service(ForgeService.self)
            let library = self.library
            guard let forge = ForgeService.forge else {
                return .run {
                    service.set(.exported(id: meta.id, ExportOutcome(archive: nil, report: nil,
                                                                      failure: ForgeServiceError.notConnected.localizedDescription)))
                    await ForgeService.tickets.fail(meta.ticket, ForgeServiceError.notConnected)
                }
            }
            return .run {
                do {
                    let (report, url) = try await forge.export(meta.id, to: .zip(meta.archive), options: meta.options)
                    service.set(.exported(id: meta.id, ExportOutcome(archive: url.path, report: report, failure: nil)))
                    library.refreshSoon()
                    await ForgeService.tickets.resolve(meta.ticket, with: .exported(report, url))
                } catch {
                    // The report of a gate that refused is on disk as package/; the page says why in words.
                    service.set(.exported(id: meta.id, ExportOutcome(archive: nil, report: nil, failure: error.localizedDescription)))
                    library.refreshSoon()
                    await ForgeService.tickets.fail(meta.ticket, error)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
