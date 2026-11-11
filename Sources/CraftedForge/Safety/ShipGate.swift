//  WHAT: The last check before a package leaves: no secret, no private path, no licence the package cannot carry.
//  OUT:  Forge.assemble (the "ship" gate).
//  TODO(forge-gates track): the scans. This stub passes everything so the flow runs end to end.

import Foundation

public enum ShipGate {
    public static func check(package: URL) -> GateResult {
        GateResult(name: "ship", passed: true, detail: ["Not scanned yet: the ship gate is pending."])
    }
}
