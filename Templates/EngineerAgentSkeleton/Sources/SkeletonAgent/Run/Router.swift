//  WHAT: One call, start to answer: the host's folder filled in, the command read (or interpreted from `brief` by the
//        host's model), the arguments checked, the command's handler run, its products emitted the way the call asked
//        to be presented, and the answer made.
//  IN:   The decoded AgentInput and the host's offer.
//  OUT:  AgentResult, or a refusal whose sentence is the fix.
//  PIN:  NOTHING IS WRITTEN UNTIL EVERYTHING IS MADE. Handlers return products; the emitters plan every file and land
//        them together, so a call that fails half way leaves the folder as it was.

import Foundation
import GraniteAgents

enum Router {
    static func answer(_ input: AgentInput, host: AgentHost, note: @escaping @Sendable (String) -> Void) async throws -> AgentResult {
        var input = input
        // The folder is the input's, else the host's: a host calling over the wire may say it only there.
        if input.directory == nil { input.directory = host.directory }
        let read = try await Interpreter.read(input, host: host)
        guard let command = read.command else { throw Refusals.noCommand(modelOffered: host.model != nil) }
        let kit = try CommandKit(command: command.rawValue, input: read, host: host, note: note)
        let products = try await Dispatch.run(command, read, kit)
        let presentation = read.present ?? Surface.presentation(command)
        return try await Emitter.emit(products, command: command.rawValue, presentation: presentation, output: read.output, kit: kit)
    }
}
