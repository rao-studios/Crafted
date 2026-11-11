//  WHAT: Runs async work against a deadline: the work's answer, or `DeadlinePassed` once the seconds run out, with
//        the work cancelled (Granite's installer and process client end their child processes on cancel).
//  OUT:  SwiftToolchain's install and perform.

import Foundation

struct DeadlinePassed: Error, CustomStringConvertible {
    let seconds: Double
    var description: String { "did not finish in \(Int(seconds)) s" }
}

func withDeadline<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
            throw DeadlinePassed(seconds: seconds)
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw CancellationError() }
        return first
    }
}
