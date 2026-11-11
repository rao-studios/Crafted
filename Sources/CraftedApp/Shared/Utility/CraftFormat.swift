import SwiftUI

/// Short numbers, durations and paths for tight rows: the cockpit's, the transcript's, Settings'.
enum CraftFormat {
    /// 950 → "950", 3_512 → "3.5k", 2_100_000 → "2.1M".
    static func count(_ n: Int) -> String {
        switch n {
        case ..<1_000: return "\(n)"
        case ..<1_000_000: return String(format: "%.1fk", Double(n) / 1_000)
        default: return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }

    /// "40s", "12m", "3h 12m", "2d 4h".
    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        switch s {
        case ..<60: return "\(s)s"
        case ..<3_600: return "\(s / 60)m"
        case ..<86_400: return "\(s / 3_600)h \(s % 3_600 / 60)m"
        default: return "\(s / 86_400)d \(s % 86_400 / 3_600)h"
        }
    }

    /// A step's time, fine enough for a pipeline's quick steps: "4 ms", "0.8s", "12s", "3m".
    static func fine(_ seconds: TimeInterval) -> String {
        if seconds < 0.1 { return "\(max(Int((seconds * 1000).rounded()), 0)) ms" }
        return seconds < 10 ? String(format: "%.1fs", seconds) : duration(seconds)
    }

    static func ago(_ date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        return seconds < 60 ? "just now" : duration(seconds) + " ago"
    }

    static func bytes(_ n: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .memory)
    }

    static func tilde(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    /// The last path component of a model id.
    static func short(_ id: String) -> String {
        id.split(separator: "/").last.map(String.init) ?? id
    }
}
