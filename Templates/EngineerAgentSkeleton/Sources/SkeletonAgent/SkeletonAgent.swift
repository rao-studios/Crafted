//  WHAT: Skeleton Template, as a Granite agent package. A call names a command and its arguments, or says what it
//        wants in `brief` and the host's model picks the command; the router reads the arguments, runs the ported
//        logic (SkeletonCore) through the command's handler, and writes what it made: files, a Canvas picture or
//        series, or a hand-off for the next agent.
//  IN:   AgentInput (Surface/, generated from the port's commands.json): the command, its arguments, and the fields
//        every command shares (`brief`, `handoff`, `present`, `output`, `seed`, `directory`).
//  OUT:  AgentResult, a `granite-answer/1` answer: the files written, the facts found, notes.
//  PIN:  FIXED. This file, the record, the router and the emitters are the template's; the surface is generated and
//        the handlers and logic are the port's. Nothing here changes when the port does.

import Foundation
import GraniteAgents

public struct SkeletonAgent: GraniteAgentPackage {
    public typealias Input = AgentInput
    public typealias Event = AgentFrame
    public typealias Output = AgentResult
    public typealias Compute = Void

    public static let word = "skeletonword"
    public static let summary = Surface.summary
    public static let fields = Surface.fields
    public static let guide = Surface.guide
    public static let makes = Surface.makes
    /// A call reads, computes and writes in well under a second; a report waits on WebKit, which lives on main.
    public static let lanes: Int? = 2

    public static func output(from events: [AgentFrame]) -> AgentResult? { events.compactMap(\.result).last }

    public init() {}

    public func run(_ input: AgentInput, context: Context) -> AsyncThrowingStream<AgentFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let host = context.host
                    let result = try await Router.answer(input, host: host) { line in
                        host.note(line)
                        continuation.yield(.note(line))
                    }
                    continuation.yield(.answered(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
