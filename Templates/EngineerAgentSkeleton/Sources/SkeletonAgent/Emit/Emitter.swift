//  WHAT: A handler's products written the way the call asked: as files a person reads (output), as what Canvas shows
//        (canvas: pictures, paged PDFs, series), or as one hand-off for the next agent (context). Then the answer.
//  IN:   The products, the command, the presentation, the call's `output` folder, the kit.
//  OUT:  AgentResult, every file it names on disk.
//  PIN:  PLANNED, THEN LANDED. Each emitter plans files into the draft; FileLanding writes them together or not at all.

import Foundation
import GraniteAgents

enum Emitter {
    static func emit(_ products: [Product], command: String, presentation: Presentation, output: String?,
                     kit: CommandKit) async throws -> AgentResult {
        let place = try FilePlace(directory: kit.directory, output: output, word: SkeletonAgent.word)
        var draft = EmitDraft(command: command, place: place)
        switch presentation {
        case .output: OutputEmitter.emit(products, into: &draft)
        case .canvas: try await CanvasEmitter.emit(products, into: &draft)
        case .context: try ContextEmitter.emit(products, into: &draft, kit: kit)
        }
        let landed = try FileLanding.land(draft.files, under: kit.directory)
        var expected = Surface.expected(command)
        if presentation == .context { expected.append(AgentExpected(kind: "handoff", name: command)) }
        return draft.answer(landed: landed, expected: expected)
    }
}
