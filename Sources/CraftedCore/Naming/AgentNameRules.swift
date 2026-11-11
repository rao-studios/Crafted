//  WHAT: The rules a generated agent's word must keep to be listed: the store's pattern, and not a word Craft or a
//        Rao agent already owns.
//  IN:   craft.rao.nyc app/(store)/_lib/listing-rules.ts (`^[a-z][a-z0-9]{1,31}$`, stricter than Granite's, which
//        allows hyphens); Craft's built-in worker and harness kinds; the Rao agent repositories (2026-11-10).
//  PIN:  UNIQUENESS IS THE STORE'S. Whether a word is taken in the store cannot be known offline; the store refuses
//        a clash when the repository is listed, and the listing form says so.

import Foundation

public enum AgentNameRules {
    /// Words Craft runs already, built in or from the Rao agent repositories.
    public static let reserved: Swift.Set<String> = [
        // Craft's worker, harness and other built-in kinds.
        "reader", "explorer", "searcher", "annotator", "judge", "shell", "server",
        "mentions", "look", "expand", "illustrate", "sourcing", "judicator", "compaction", "thread", "knowledge",
        "git", "coder", "echo", "watch",
        // Rao's agent packages.
        "marble", "plate", "assets", "design", "docs", "granite", "localize", "loom", "mocks", "models",
        "moderation", "network", "platform", "screenshots", "stoic", "tests", "comic", "blackjack",
        // Crafted's own templates.
        "skeletonword", "atelierword",
    ]

    /// Why a word cannot be listed, or nil.
    public static func wordProblem(_ word: String) -> String? {
        if word.isEmpty { return "Give the agent a word: what Craft calls it by." }
        if word.count < 2 || word.count > 32 { return "A word is 2 to 32 characters." }
        guard let first = word.first, first.isASCII, first.isLowercase, first.isLetter else {
            return "A word starts with a lowercase letter."
        }
        guard word.allSatisfy({ $0.isASCII && (($0.isLetter && $0.isLowercase) || $0.isNumber) }) else {
            return "A word is lowercase letters and digits only, with no spaces or hyphens."
        }
        if reserved.contains(word) { return "\"\(word)\" is already an agent Craft runs. Choose another." }
        return nil
    }
}
