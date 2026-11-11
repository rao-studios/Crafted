//  WHAT: Where the painting's wash should be for a run: each forge stage owns a band of the painting by its weight;
//        the wash fills the current band by the stage's fraction, or creeps through it by time when the stage gives
//        none; and the drawn position eases toward that target.
//  IN:   The run's stages, the current stage's id, its fraction (nil when unknown), the finished stages' ids, how
//        long the current stage has run.
//  OUT:  0…1, for ScenePainting(progress:).
//  PIN:  NEVER AHEAD OF THE ENGINE. The target never leaves the current stage's band: a fraction past 1 stops at the
//        band's end (the next band's start, which is not inside it), and a stage with no fraction creeps toward 85%
//        of its band, never past, however long it runs. The next band is entered only when the engine starts or
//        finishes a stage.
//  PIN:  Pure: no clock, no state. The caller passes the elapsed time and the last drawn value; `selfCheck` holds the
//        table it was checked against.

import CraftedForge
import Foundation

enum WashProgress {
    /// How far a stage with no fraction creeps through its band: toward `creepCeiling`, half way after `creepHalf`.
    static let creepCeiling = 0.85
    static let creepHalf: TimeInterval = 30
    /// The drawn wash's lag behind the target.
    static let easing: TimeInterval = 0.9

    static func target(stages: [ForgeStage], current: String?, fraction: Double?, finished: Set<String>, stageElapsed: TimeInterval) -> Double {
        let weights = stages.map { max($0.weight, 0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }

        // Each stage's band: [start, end) of the painting.
        var bands: [(start: Double, end: Double)] = []
        var start = 0.0
        for weight in weights {
            let end = start + weight / total
            bands.append((start, end))
            start = end
        }

        // The furthest the engine has said is done.
        let done = stages.indices.filter { finished.contains(stages[$0].id) }.map { bands[$0].end }.max() ?? 0

        guard let current, let index = stages.firstIndex(where: { $0.id == current }) else {
            return min(done, 1)
        }
        let band = bands[index]
        if finished.contains(current) { return min(band.end, 1) }

        let within: Double
        if let fraction, fraction.isFinite {
            within = min(max(fraction, 0), 1)
        } else {
            let t = max(stageElapsed, 0)
            within = creepCeiling * t / (t + creepHalf)
        }
        return min(band.start + (band.end - band.start) * within, 1)
    }

    /// The next drawn value, `dt` seconds after `previous`, approaching `target` with a 0.9 s time constant.
    static func displayed(previous: Double, target: Double, dt: Double) -> Double {
        guard previous.isFinite else { return target.isFinite ? min(max(target, 0), 1) : 0 }
        guard target.isFinite, dt > 0 else { return previous }
        let next = previous + (target - previous) * (1 - exp(-dt / easing))
        return abs(target - next) < 0.0005 ? target : min(max(next, 0), 1)
    }

    #if DEBUG
    /// The table the two functions were checked against. Run from a debug build (or a test) to recheck.
    static func selfCheck() {
        let stages = [
            ForgeStage(id: "a", title: "A", part: .analysis, weight: 1),
            ForgeStage(id: "b", title: "B", part: .analysis, weight: 2),
            ForgeStage(id: "c", title: "C", part: .generation, weight: 1),
        ]
        func near(_ x: Double, _ y: Double) -> Bool { abs(x - y) < 1e-9 }
        func target(_ current: String?, _ fraction: Double?, _ finished: Set<String> = [], _ elapsed: TimeInterval = 0) -> Double {
            Self.target(stages: stages, current: current, fraction: fraction, finished: finished, stageElapsed: elapsed)
        }

        // Bands: a [0, 0.25), b [0.25, 0.75), c [0.75, 1].
        assert(near(target("a", 0.5), 0.125), "half of the first band")
        assert(near(target("b", 0, ["a"]), 0.25), "the second band's start")
        assert(near(target("b", 0.5, ["a"]), 0.5), "half of the second band")
        assert(near(target("b", 7, ["a"]), 0.75), "a fraction past 1 stops at the band's end")
        assert(near(target("b", -1, ["a"]), 0.25), "a negative fraction stops at the band's start")
        assert(near(target("b", nil, ["a"], 0), 0.25), "no fraction, no time: the band's start")
        assert(near(target("b", nil, ["a"], 30), 0.25 + 0.5 * 0.425), "no fraction: half of 85% after 30 s")
        assert(target("b", nil, ["a"], 1e9) < 0.25 + 0.5 * 0.85 + 1e-6, "no fraction: never past 85% of the band")
        assert(target("b", nil, ["a"], 600) > target("b", nil, ["a"], 60), "no fraction: still creeping after minutes")
        assert(near(target("b", 0.3, ["a", "b"]), 0.75), "a finished current stage fills its band")
        assert(near(target(nil, nil, ["a", "b"]), 0.75), "between stages: the finished bands")
        assert(near(target(nil, nil, ["a", "b", "c"]), 1), "all finished: painted")
        assert(near(target(nil, nil, []), 0), "nothing started: paper")
        assert(near(target("zzz", 0.5, ["a"]), 0.25), "an unknown stage: the finished bands")
        assert(near(Self.target(stages: [], current: "a", fraction: 1, finished: [], stageElapsed: 0), 0), "no stages: paper")

        assert(near(displayed(previous: 0.5, target: 0.5, dt: 1), 0.5), "at rest stays")
        assert(abs(displayed(previous: 0, target: 1, dt: 0.9) - (1 - exp(-1))) < 1e-9, "one time constant: 63%")
        assert(near(displayed(previous: 0.2, target: 0.8, dt: 0), 0.2), "no time, no change")
        assert(near(displayed(previous: 0.2, target: 0.8, dt: 60), 0.8), "settles on the target")
        assert(displayed(previous: 0.6, target: 0.4, dt: 0.1) < 0.6, "follows a target that moves back")
    }
    #endif
}
