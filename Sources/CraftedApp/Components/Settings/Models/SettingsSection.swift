import Foundation

/// A page of Settings. Grouped in the sidebar; a new global knob joins a page before it earns one.
enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case general
    case models
    case about

    var id: String { rawValue }

    /// The sidebar's groups, in order; a rule between them. The whole app's first (who you are, how it looks, the
    /// models it runs), then this build, alone at the foot of the sidebar (`SettingsSidebar` pins the last group there).
    static let groups: [[SettingsSection]] = [[.general, .models], [.about]]

    /// Every section in sidebar order: what the arrow keys walk.
    static var ordered: [SettingsSection] { groups.flatMap { $0 } }

    var title: String {
        switch self {
        case .general: return "General"
        case .models: return "Models"
        case .about: return "About"
        }
    }

    /// The title, where the sidebar has less room.
    var sidebarTitle: String { title }

    var subtitle: String {
        switch self {
        case .general: return "Who you are to Crafted, the name your agents credit, and how it looks."
        case .models: return "The two models Crafted runs on this Mac, in the folder Craft shares: what is here, and downloads."
        case .about: return "This build of Crafted, and where it keeps what it makes."
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .models: return "cpu"
        case .about: return "info.circle"
        }
    }
}
