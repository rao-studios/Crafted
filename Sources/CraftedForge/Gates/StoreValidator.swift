//  WHAT: The store's static check of a package, ported rule for rule from craft.rao.nyc's validator
//        (app/(store)/_lib/formats/swift-package/{index,manifest,sources}.ts, source/listing-json.ts, listing-rules.ts):
//        what the store will refuse, caught before the person pushes.
//  OUT:  Forge.assemble (the "store" gate).
//  TODO(forge-gates track): the port. This stub passes everything so the flow runs end to end.

import CraftedCore
import Foundation

public enum StoreValidator {
    public static func check(package: URL, identity: AgentIdentity) -> GateResult {
        GateResult(name: "store", passed: true, detail: ["Not checked yet: the validator port is pending."])
    }
}
