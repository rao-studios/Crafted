//  WHAT: `crafted-check validate`: the static gates on any package folder, without building it: the store's
//        validator (with the identity read off its listing and its word) and the ship gate.
//  OUT:  Exit 0 when both pass.

import CraftedCore
import CraftedForge
import Foundation

enum ValidateCommand {
    static let usage = "crafted-check validate [--name NAME] [--word WORD] <package>"

    static func run(_ arguments: CheckArguments) async -> Int32 {
        let package: URL
        do { package = try arguments.folder() } catch { return ForgeCommand.fail("\(error)\n\n" + usage) }
        let listing = (try? Data(contentsOf: package.appendingPathComponent("Assets/listing.json")))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let name = arguments.value("name") ?? (listing?["name"] as? String) ?? package.lastPathComponent
        let word = arguments.value("word") ?? StoreValidator.inspect(package: package).word
        let identity = AgentIdentity.derive(display: name, word: word)
        print("[identity] \(identity.display) · \(identity.package) · $\(identity.word)")
        let gates = [StoreValidator.check(package: package, identity: identity), ShipGate.check(package: package)]
        for gate in gates { print(EventLine.gate(gate)) }
        return gates.allSatisfy { $0.passed || $0.skipped } ? 0 : 1
    }
}
