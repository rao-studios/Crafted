import AppKit
import CraftedRuntime
import Foundation

/// The windows that are not a page's: the Workshop (the library and a generation), Settings, the onboarding.
enum Surface: Equatable {
    case workshop
    case settings(SettingsSection?)
    case onboarding
}

extension CraftedAppRoot {
    /// Shows a window. The Workshop waits for the onboarding gate; Settings (Models among its pages) and the onboarding
    /// itself never do.
    func show(_ surface: Surface) {
        switch surface {
        case .workshop:
            guard !holdsBack() else { return }
            MainWindowController.show()
        case .settings(let section):
            if let section { environment.set(.settingsSection(section)) }
            SettingsWindowController.show()
        case .onboarding:
            OnboardingWindowController.show()
        }
    }

    func dismiss(_ surface: Surface) {
        switch surface {
        case .onboarding: OnboardingWindowController.dismiss()
        case .workshop, .settings: break
        }
    }

    // MARK: - Routes

    /// The library: Home's drop leaf and the grid.
    func showLibrary() {
        environment.set(.route(.library))
        library.refreshSoon()
        show(.workshop)
    }

    /// One generation: its run, its interpretations or its listing, by where it stands (WorkshopRules).
    func open(generation id: String) {
        environment.set(.route(.generation(id)))
        show(.workshop)
    }
}
