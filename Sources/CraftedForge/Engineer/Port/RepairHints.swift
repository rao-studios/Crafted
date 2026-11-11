//  WHAT: A hint for a failure, by what the compiler or a vector said: the fix a port most often needs for it, in a
//        sentence. Rides in the repair prompt beside the trimmed diagnostics.

import Foundation

public enum RepairHints {
    static let table: [(String, String)] = [
        ("cannot find '", "It names something not declared: a unit sees Foundation, its contract, the domain types, the other units, CoreFailure and CoreResources; a handler also sees the kit, the arguments and Product."),
        ("does not conform to protocol", "Every contract function must be `public static` with exactly the contract's argument labels, types and return type."),
        ("cannot convert value of type 'Int' to expected argument type 'Double'", "Swift does not mix Int and Double: convert with Double(x)."),
        ("cannot convert value of type 'Double' to expected argument type 'Int'", "Swift does not mix Int and Double: convert with Int(x) after rounding as the source does."),
        ("binary operator", "Both sides of an operator must have one type: convert with Double(x) or Int(x)."),
        ("is not concurrency-safe", "Swift 6 forbids shared mutable state: use `static let`, never `static var`."),
        ("call can throw but is not marked with 'try'", "Mark each throwing call with `try`."),
        ("missing return", "Every path of the function must return a value or throw."),
        ("has no member", "That member does not exist on the type: use what the contract, the types and Foundation declare."),
        ("extra argument", "The call has an argument the function does not take: match the declared labels."),
        ("missing argument", "The call leaves out an argument: give every label the function declares."),
        ("expected", "A syntax error: look at the line and the one before it."),
        ("value of optional type", "Unwrap the optional with `guard let` and throw CoreFailure.invalid with the fix."),
        ("ambiguous", "Say the type: annotate the constant or convert the literal."),
        ("vector", "A vector fails: compare its arithmetic and rounding with the source line by line; the hazard sheet lists what ports get wrong."),
        ("expected an error", "The source refuses this input: throw CoreFailure.invalid with a sentence saying the fix."),
        ("fact", "The canonical call's facts differ: return `.value(name, number)` with the names the call expects."),
    ]

    public static func hint(for lines: [String]) -> String? {
        for line in lines {
            for (needle, hint) in table where line.contains(needle) { return hint }
        }
        return nil
    }
}
