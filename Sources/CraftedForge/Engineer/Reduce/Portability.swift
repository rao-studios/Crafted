//  WHAT: Whether a use case can become a command, by code: pure or file in and file out, one stateless process, no live
//        interface, network, private service, hardware or secret, and checkable. What it needs that a command can
//        stand in for is said as a change: the clock becomes an `asOf` argument, randomness a `seed`, saved state a
//        state file, a prompt an argument.
//  PIN:  A CHAIN WITH NO RULE IS PLUMBING. It is dropped here, whatever its title.

import Foundation

public enum Portability {
    public static func judge(_ usecase: UseCase) -> UseCase.Portability {
        var reasons: [String] = []
        var change: [String] = []
        let needs = usecase.needs
        if needs.ui { reasons.append("it needs a live interface") }
        if needs.network { reasons.append("it reaches the network") }
        if needs.secret { reasons.append("it needs a secret") }
        if needs.hardware { reasons.append("it needs hardware") }
        if needs.process { reasons.append("it runs other processes") }
        if usecase.rules.isEmpty { reasons.append("it applies no rule: it is plumbing") }
        if usecase.inputs.count > 6 { change.append("its \(usecase.inputs.count) inputs are split across commands of six arguments at most") }
        if needs.clock { change.append("the clock becomes an `asOf` argument") }
        if needs.random { change.append("randomness takes a `seed`") }
        if needs.state { change.append("saved state becomes a state file the call names") }
        if !usecase.verifiability.derivable && usecase.verifiability.sourceTests.isEmpty && usecase.verifiability.examples.isEmpty {
            reasons.append("nothing could check it: no tests, no examples, nothing derivable")
        }
        let verdict = !reasons.isEmpty ? "not-portable" : (change.isEmpty ? "portable" : "portable-with-change")
        return UseCase.Portability(verdict: verdict, change: change, reasons: reasons)
    }
}
