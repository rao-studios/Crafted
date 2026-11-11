//  WHAT: Crafted's two models as a service: whether each is on this Mac (read from disk, never kept as a flag), what is
//        downloading, what this Mac can hold — and the work that changes them: the disk read, downloads one at a time
//        (vision first), cancel, and remove.
//  IN:   CraftedMLX (ModelLocator, ModelDownloader, ModelRemover, MemoryPlan), ModelCatalog.
//  OUT:  ModelService+Center, Reducers/ModelService.{Set,Refresh,Download,Cancel,Remove}, Ops/ModelOps.
//  PIN:  THE SHARED HOME. Models live in ~/.rao/models/huggingface (AII_HOME moves it), where Craft keeps them: a copy
//        Craft downloaded is found and never fetched twice, and a copy removed here is gone for Craft too.
//  PIN:  ONE DOWNLOAD AT A TIME, IN CATALOG ORDER. "Download both" queues both; the small vision model goes first so its
//        card turns green early. A request carries an id that `reduce` adopts only when nothing is in flight, so a
//        second request queues instead of starting a second download (Granite rule 8b).
//  PIN:  "INSTALLED" IS A DISK READ. A cancelled Hub download can return normally, so the end of every download reads
//        the disk again; only `ModelLocator` says a model is there.
//  PIN:  NEVER LOADS A MODEL. Loading is MLXModelRuntime's, through the forge; this service only reads and writes disk.

import CraftedCore
import CraftedMLX
import Foundation
import Granite
import GraniteAgents

public struct ModelService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    static let tickets = GraniteTickets<ModelServiceReply>()
    static let runs = RunRegistry()
    /// The home every reducer reads; the self-test and the root may point it elsewhere before the first send.
    static let homes = TransientRegistry<ModelHome>()

    static var home: ModelHome { homes.get("home") ?? .standard }

    /// Where the models live, for a page to show: ~/.rao/models/huggingface unless AII_HOME moved it.
    public static var homePath: String { home.huggingFace.path }
}

extension ModelService: @unchecked Sendable {}

extension ModelService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// Reads the disk again: which models are here, at which commit, and what this Mac has room for.
    @discardableResult
    public func refresh() async -> [ModelStatus] {
        let ticket = await Self.tickets.open()
        hop { $0.center.refresh.send(Refresh.Meta(ticket: ticket.id)) }
        guard case .catalog(let statuses)? = try? await Self.tickets.wait(ticket.id) else { return [] }
        return statuses
    }

    public func refreshSoon() { hop { $0.center.refresh.send(Refresh.Meta(ticket: nil)) } }

    /// Downloads `kinds` (missing ones only), one at a time in catalog order. Resumes a stopped download.
    public func download(_ kinds: [ModelKind]) {
        hop { $0.center.download.send(Download.Meta(id: UUID(), kinds: kinds)) }
    }

    /// Both models, vision first.
    public func downloadAll() { download(ModelCatalog.all.map(\.kind)) }

    /// Stops the download in flight and empties the queue. What was fetched stays, for the next download to resume.
    public func cancelDownload() { hop { $0.center.cancel.send(Cancel.Meta()) } }

    /// Deletes a model's copy from the shared home (Craft's copy too). Answers the bytes freed.
    @discardableResult
    public func remove(_ kind: ModelKind) async -> Int64? {
        let ticket = await Self.tickets.open()
        hop { $0.center.remove.send(Remove.Meta(ticket: ticket.id, kind: kind)) }
        guard case .removed(let bytes)? = try? await Self.tickets.wait(ticket.id) else { return nil }
        return bytes
    }

    private func hop(_ body: @escaping @Sendable (ModelService) -> Void) {
        let service = self
        onMain { body(service) }
    }
}
