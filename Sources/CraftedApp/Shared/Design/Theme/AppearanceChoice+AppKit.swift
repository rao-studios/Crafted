import AppKit
import CraftedRuntime

extension AppearanceChoice {
    /// The app-wide appearance `CraftedAppRoot.applyAppearance` sets: nil follows macOS. Every window,
    /// popover and alert inherits it.
    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}
