//  WHAT: A call that names no command, read into one: what the person asked (`brief`, else the host's ask) goes to the
//        host's model once, with the agent's schema and guide, and the call it writes is merged under the fields the
//        caller gave.
//  OUT:  Router.
//  PIN:  ONE ASK, NEVER A GUESS. With no model, or no words to read, the call is refused as `call`, listing every
//        command with its arguments, so the caller can name one.
//  PIN:  THE CALLER'S FIELDS WIN. The model fills only what the call left out; `directory` is never the model's.

import Foundation
import GraniteAgents

enum Interpreter {
    static func read(_ input: AgentInput, host: AgentHost) async throws -> AgentInput {
        if input.command != nil { return input }
        let words = [input.brief, host.ask].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let model = host.model, !words.isEmpty else { throw Refusals.noCommand(modelOffered: host.model != nil) }
        let schema = GraniteSchema.of(AgentInput.self).jsonSchema(notes: Surface.fields, hiding: ["directory", "brief", "handoff"])
        let answer: Data
        do {
            answer = try await model.object(schema: schema, system: Surface.interpreterSystem, user: words.joined(separator: "\n"),
                                            maxTokens: 800, seconds: 120)
        } catch {
            throw AgentRefusal(.model, "The host's model could not read the request into a command (\(error)): name the command and its arguments.")
        }
        let merged = try merge(given: input, read: answer)
        guard merged.command != nil else {
            throw AgentRefusal(.model, "The host's model named no command: " + Refusals.commandList)
        }
        return merged
    }

    /// `read`'s fields under `given`'s: a field the caller set is kept, and the model's `directory` is dropped.
    static func merge(given: AgentInput, read: Data) throws -> AgentInput {
        let mine = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(given))) as? [String: Any] ?? [:]
        var theirs = (try? JSONSerialization.jsonObject(with: read)) as? [String: Any] ?? [:]
        theirs.removeValue(forKey: "directory")
        let merged = theirs.merging(mine) { _, kept in kept }
        do {
            return try JSONDecoder().decode(AgentInput.self, from: JSONSerialization.data(withJSONObject: merged))
        } catch {
            throw AgentRefusal(.model, "The host's model wrote a call that does not read (\(error)): name the command and its arguments.")
        }
    }
}
