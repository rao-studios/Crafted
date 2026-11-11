import Foundation

/// What keeps macOS from napping Crafted while a model works: a user-initiated activity, held for exactly as long as a
/// load or a generation runs, whether or not a Crafted window is in front.
///
/// PIN: AN APP NOT IN FRONT IS THROTTLED (Craft, 2026-11-10). App Nap puts a backgrounded app at background QoS and
/// MLX's CPU side runs dozens of times slower while the GPU waits: ~22 tok/s fell to 0.4. A run takes minutes to hours
/// and the person will look away, so every load and every ask holds this.
enum GenerationActivity {
    /// What `pmset -g assertions` shows while it is held.
    static let reason = "Crafted is running a model"

    /// Runs `work` with the activity held, ending it however `work` ends.
    static func held<T>(_ work: () async throws -> T) async rethrows -> T {
        let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: reason)
        defer { ProcessInfo.processInfo.endActivity(activity) }
        return try await work()
    }
}
