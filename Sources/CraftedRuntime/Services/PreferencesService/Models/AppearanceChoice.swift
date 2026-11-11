import Foundation

/// How Crafted looks: as macOS does, on cream paper, or on graphite. Settings › General writes it; the app root applies
/// it to every window at once.
public enum AppearanceChoice: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    /// The segment's label in Settings › General.
    public var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
