//  WHAT: Which source a style takes a value from, when several have one: what the designer declared, then what code
//        measured, then what the vision model saw, then what the coder model inferred. Each value is kept with the
//        rung it came from, so provenance can say why.
//  PIN:  MEASURED BEATS SEEN BEATS GUESSED. A model's answer fills only what nothing more certain fixed.

import Foundation

public enum TrustOrder {
    public enum Source: String, Codable, Sendable, CaseIterable { case declared, measured, observed, inferred }

    public static func pick<T>(declared: T? = nil, measured: T? = nil, observed: T? = nil, inferred: T? = nil) -> (value: T, source: Source)? {
        if let declared { return (declared, .declared) }
        if let measured { return (measured, .measured) }
        if let observed { return (observed, .observed) }
        if let inferred { return (inferred, .inferred) }
        return nil
    }
}
