//  WHAT: The notes one call over the wire said, kept in order for its CallOutcome.

import Foundation

/// The notes a call said, in order.
final class NoteLog: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [String] = []
    func add(_ line: String) { lock.withLock { kept.append(line) } }
    var lines: [String] { lock.withLock { kept } }
}
