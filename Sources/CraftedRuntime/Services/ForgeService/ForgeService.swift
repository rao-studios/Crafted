//  WHAT: The forge as a service: the one run in flight (its stages, progress, the question it waits on, the three
//        interpretations), the person's answers back into it, cancel and resume, an update from a folder, and the
//        download (assemble, check, zip).
//  IN:   The Forge (CraftedForge), connected at boot by the runtime root with its model (live or scripted), the
//        toolchain and the templates.
//  OUT:  ForgeService+Center, Reducers/ForgeService.{Set,Start,Answer,Cancel,Export}, Ops/ForgeOps.
//  PIN:  ONE RUN AT A TIME: one model fits in memory at a time. `Start` adopts a request only when no run is live and
//        no start is pending; a second is refused (its ticket fails `busy`).
//  PIN:  THE RUN'S EVENTS ARE THE STATE. A consumer Task per run (registered in `runs`) maps `ForgeRun.events` into
//        state through `set`, coalescing progress to ten a second; the ForgeRun itself is a resident (`live`), reached
//        by id for choose, steer, decide and cancel.
//  PIN:  STORED RELAYS POINT DOWN: Start and Export relay to LibraryService (a leaf) to refresh the grid when a run's
//        events change a record; nothing below relays back here.

import CraftedCore
import CraftedForge
import Foundation
import Granite
import GraniteAgents

public struct ForgeService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    static let tickets = GraniteTickets<ForgeReply>()
    /// The consumer of each run's events, by generation id.
    static let runs = RunRegistry()
    /// The Forge, put by the runtime root at boot.
    static let forges = TransientRegistry<Forge>()
    /// Each live ForgeRun, by generation id.
    static let live = TransientRegistry<ForgeRun>()

    public static var forge: Forge? { forges.get("forge") }
}

extension ForgeService: @unchecked Sendable {}

extension ForgeService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// The root's boot: the forge every reducer works through. Put before any send.
    public func connect(_ forge: Forge) { Self.forges.put("forge", forge) }

    // MARK: - Runs

    /// A new generation for `folder`, as `role`. Answers its id once the run has started.
    @discardableResult
    public func start(folder: URL, role: CraftedRole, options: ForgeOptions) async throws -> String {
        try await begin(.new(folder: folder, role: role), options: options)
    }

    /// An interrupted or failed generation, picked up from its ledger.
    @discardableResult
    public func resume(_ id: String, options: ForgeOptions) async throws -> String {
        try await begin(.resume(id), options: options)
    }

    /// A generation run again over `folder` (the project, changed): unchanged files are not read again.
    @discardableResult
    public func update(_ id: String, from folder: URL, options: ForgeOptions) async throws -> String {
        try await begin(.update(id, folder: folder), options: options)
    }

    private func begin(_ request: Start.Meta.Request, options: ForgeOptions) async throws -> String {
        let ticket = await Self.tickets.open()
        hop { $0.center.start.send(Start.Meta(ticket: ticket.id, id: UUID(), request: request, options: options)) }
        guard case .started(let id) = try await Self.tickets.wait(ticket.id) else { throw ForgeServiceError.badReply }
        return id
    }

    /// Engineer: one of the three interpretations (zero-based).
    public func choose(_ index: Int, in id: String) { answer(.choose(index), in: id) }

    /// Engineer: none of the three; the person's words steer the next three.
    public func steer(_ text: String, in id: String) { answer(.steer(text), in: id) }

    /// The person's answer to the question the run waits on.
    public func decide(_ decisionID: String, _ answer: DecisionAnswer, in id: String) {
        self.answer(.decide(decisionID, answer), in: id)
    }

    private func answer(_ answer: Answer.Meta.Reply, in id: String) {
        hop { $0.center.answer.send(Answer.Meta(id: id, reply: answer)) }
    }

    /// Stops the run; it stays resumable.
    public func cancel(_ id: String) { hop { $0.center.cancel.send(Cancel.Meta(id: id)) } }

    // MARK: - Download

    /// Assembles the generation with its saved listing and icon, runs the gates, and zips it to `archive`.
    @discardableResult
    public func export(_ id: String, to archive: URL, options: ForgeOptions) async throws -> (PackageReport, URL) {
        let ticket = await Self.tickets.open()
        hop { $0.center.export.send(Export.Meta(ticket: ticket.id, request: UUID(), id: id, archive: archive, options: options)) }
        guard case .exported(let report, let url) = try await Self.tickets.wait(ticket.id) else { throw ForgeServiceError.badReply }
        return (report, url)
    }

    private func hop(_ body: @escaping @Sendable (ForgeService) -> Void) {
        let service = self
        onMain { body(service) }
    }
}
