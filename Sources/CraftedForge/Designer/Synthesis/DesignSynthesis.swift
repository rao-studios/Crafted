//  WHAT: The synthesise stage: the coder model made resident once, then five small asks (colour, type, layout,
//        imagery and motifs, voice), each with its LOCKED facts and what is YOURS, each answer held to what it may say
//        (letters of the palette, families from AVAILABLE, engines and formats the kit has, motif CSS that draws a shape,
//        samples copied from the words read). Answers are kept in the run's ledger, keyed by their prompt.
//  PIN:  A PART THAT FAILS IS A PART LEFT TO CODE. After its repairs a part that still breaks its rules is dropped
//        with a finding; reconcile fills it from what was measured and seen, so one bad answer never ends the run.

import CraftedCore
import Foundation

public struct SynthesisResult: Codable, Sendable, Equatable {
    public var colour: ColourAnswer?
    public var type: TypeAnswer?
    public var layout: LayoutAnswer?
    public var imagery: ImageryAnswer?
    public var voice: VoiceAnswer?

    public init(colour: ColourAnswer? = nil, type: TypeAnswer? = nil, layout: LayoutAnswer? = nil, imagery: ImageryAnswer? = nil, voice: VoiceAnswer? = nil) {
        self.colour = colour; self.type = type; self.layout = layout; self.imagery = imagery; self.voice = voice
    }
}

public enum DesignSynthesis {
    public static func run(_ context: ForgeContext, brief: SynthesisBrief) async throws -> SynthesisResult {
        try await context.use(.coder)
        var result = SynthesisResult()
        let letters = brief.letters
        context.progress("synthesise", "Colour: which letter plays each role", fraction: 0)
        result.colour = try await ask(context, .colour, brief.colour, as: ColourAnswer.self) { checkColour($0, letters: letters) }
        context.progress("synthesise", "Type: a face for each role", fraction: 0.2)
        let available = brief.available
        result.type = try await ask(context, .type, brief.type, as: TypeAnswer.self) { checkType($0, available: available) }
        context.progress("synthesise", "Layout: an engine for each format", fraction: 0.4)
        result.layout = try await ask(context, .layout, brief.layout, as: LayoutAnswer.self, check: checkLayout)
        context.progress("synthesise", "Imagery and motifs", fraction: 0.6)
        result.imagery = try await ask(context, .imagery, brief.imagery, as: ImageryAnswer.self, check: checkImagery)
        context.progress("synthesise", "Voice: how the pieces speak", fraction: 0.8)
        let words = brief.measures.words
        result.voice = try await ask(context, .voice, brief.voice, as: VoiceAnswer.self) { checkVoice($0, words: words) }
        return result
    }

    /// One part: kept in the ledger by its prompt; a model failure after repairs is a finding and nil.
    static func ask<T: Codable & Sendable>(_ context: ForgeContext, _ purpose: DesignerPrompts.Purpose, _ user: String, as type: T.Type,
                                           check: @escaping (T) -> [String]) async throws -> T? {
        let prompt = try DesignerPrompts.prompt(purpose, user: user)
        let key = "\(purpose.rawValue).\(DesignerPrompts.version)-\(prompt.hash.prefix(16))"
        if let kept = context.ledger.get(T.self, key) { return kept }
        do {
            let answer = try await context.ask.object(.coder, prompt, as: T.self, budget: DesignerPrompts.synthesis, check: check)
            try context.ledger.put(answer, key)
            return answer
        } catch let error as ForgeError {
            if case .model = error {
                context.finding(Finding(.fallback, "The \(purpose.rawValue) answer did not hold after its repairs; the style takes that part from what was measured and seen."))
                return nil
            }
            throw error
        }
    }

    public static func checkColour(_ answer: ColourAnswer, letters: Set<String>) -> [String] {
        var problems: [String] = []
        for (role, pair) in answer.roles {
            if !DesignerStyle.colourRoles.contains(role) { problems.append("\"\(role)\" is not a role: \(DesignerStyle.colourRoles.joined(separator: ", ")).") }
            for letter in [pair.light] + (pair.dark.map { [$0] } ?? []) where !letters.contains(letter) {
                problems.append(ObservationCheck.hasHex(letter) ? "\(role) is \"\(letter)\": use the palette's letters, never a hex."
                                : "\(role) is \"\(letter)\", which is not a letter of the palette.")
            }
        }
        for gradient in answer.gradients ?? [] where gradient.stops.contains(where: { !letters.contains($0) }) {
            problems.append("gradient \(gradient.id) has a stop that is not a letter of the palette.")
        }
        return problems
    }

    public static func checkType(_ answer: TypeAnswer, available: [String]) -> [String] {
        let names = Set(available.map { $0.lowercased() })
        var problems: [String] = []
        for (role, face) in answer.roles {
            if !DesignerStyle.typeRoles.contains(role) { problems.append("\"\(role)\" is not a type role: \(DesignerStyle.typeRoles.joined(separator: ", ")).") }
            if !names.contains(face.family.lowercased()) { problems.append("\(role)'s family \"\(face.family)\" is not AVAILABLE: choose one of \(available.joined(separator: ", ")).") }
            if let weight = face.weight, !(100...900).contains(weight) { problems.append("\(role)'s weight \(weight) is not 100 to 900.") }
        }
        if answer.roles["display"] == nil && answer.roles["body"] == nil { problems.append("give at least the display and body roles.") }
        return problems
    }

    public static func checkLayout(_ answer: LayoutAnswer) -> [String] {
        var problems: [String] = []
        for rule in answer.archetypes {
            if !DesignerStyle.engines.contains(rule.engine) { problems.append("\"\(rule.engine)\" is not an engine: \(DesignerStyle.engines.joined(separator: ", ")).") }
            for format in rule.for where !DesignerStyle.formats.contains(format) { problems.append("\"\(format)\" is not a format.") }
        }
        let covered = Set(answer.archetypes.flatMap { $0.for.isEmpty ? DesignerStyle.formats : $0.for })
        let missing = DesignerStyle.formats.filter { !covered.contains($0) }
        if !missing.isEmpty { problems.append("no engine for \(missing.joined(separator: ", ")): give every format at least one.") }
        return problems
    }

    public static func checkImagery(_ answer: ImageryAnswer) -> [String] {
        var problems: [String] = []
        for motif in answer.motifs ?? [] {
            if !["background", "corner", "divider", "frame", "accent"].contains(motif.slot) { problems.append("motif \(motif.id)'s slot \"\(motif.slot)\" is not one of background, corner, divider, frame, accent.") }
            if let css = motif.css, !css.isEmpty, MotifSafety.sanitize(css).isEmpty { problems.append("motif \(motif.id)'s CSS keeps nothing that draws a shape: use the listed properties and var(--…) colours, never url().") }
            if let css = motif.css, ObservationCheck.hasHex(css) { problems.append("motif \(motif.id)'s CSS names a hex: use var(--accent) and the other variables.") }
        }
        if let placeholder = answer.placeholder, !["solid", "gradient", "duotone", "pattern"].contains(placeholder) {
            problems.append("placeholder \"\(placeholder)\" is not solid, gradient, duotone or pattern.")
        }
        return problems
    }

    public static func checkVoice(_ answer: VoiceAnswer, words: [String]) -> [String] {
        let read = Set(words.map { $0.lowercased() })
        var problems: [String] = []
        if answer.tone.isEmpty { problems.append("give two to four words of tone.") }
        for sample in answer.samples ?? [] where !read.contains(sample.lowercased()) {
            problems.append("the sample \"\(sample.prefix(40))\" is not one of the WORDS READ: copy lines exactly, or give none.")
        }
        return problems
    }
}
