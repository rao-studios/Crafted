//  WHAT: Everything a port's package is assembled from, as the run keeps it: the plan, where the port stands, the slot
//        bodies, the vectors and calls, the carried and lifted files. Loaded from the run alone.
//  PIN:  THE RUN IS ENOUGH. Assembly never opens the dropped folder: every byte it places was written here first.

import Foundation

public struct PortArtefacts: Sendable {
    public var spec: PortSpec
    public var state: PortState
    /// Template path → body.
    public var slots: [String: String]
    public var vectors: [String: VectorList]
    public var calls: [String: CallSpec]
    public var carried: [String: CarriedText]
    public var lifted: [String: CarriedText]

    public init(spec: PortSpec, state: PortState, slots: [String: String] = [:], vectors: [String: VectorList] = [:],
                calls: [String: CallSpec] = [:], carried: [String: CarriedText] = [:], lifted: [String: CarriedText] = [:]) {
        self.spec = spec; self.state = state; self.slots = slots; self.vectors = vectors; self.calls = calls
        self.carried = carried; self.lifted = lifted
    }

    /// The spec without the dropped commands (and what only they used).
    public var shipped: PortSpec { spec.dropping(state.droppedNames) }

    public static func load(_ run: RunFolder) throws -> PortArtefacts {
        guard let spec = run.read(PortSpec.self, "plan.json") else { throw ForgeError.notFound("The port's plan (plan.json)") }
        guard let state = run.read(PortState.self, "port.json") else { throw ForgeError.notFound("The port's state (port.json)") }
        var artefacts = PortArtefacts(spec: spec, state: state)
        for unit in spec.units {
            if let list = run.read(VectorList.self, "vectors/\(unit.unit).json") { artefacts.vectors[unit.unit] = list }
            if let body = run.read(SlotBody.self, SlotBody.artefact(SkeletonLayout.logic(unit.unit))) { artefacts.slots[body.path] = body.text }
        }
        for command in spec.commands {
            if let call = run.read(CallSpec.self, "calls/\(command.name).json") { artefacts.calls[command.name] = call }
            if let body = run.read(SlotBody.self, SlotBody.artefact(SkeletonLayout.handler(command.name))) { artefacts.slots[body.path] = body.text }
        }
        for resource in spec.resources {
            if let text = run.read(CarriedText.self, "carried/\(resource.name).json") { artefacts.carried[resource.name] = text }
        }
        for lift in spec.lifts {
            if let text = run.read(CarriedText.self, "lifted/\(lift.name).json") { artefacts.lifted[lift.name] = text }
        }
        return artefacts
    }
}
