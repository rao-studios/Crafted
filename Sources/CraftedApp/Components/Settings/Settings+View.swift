import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

extension Settings {
    var view: some View {
        HStack(spacing: 0) {
            SettingsSidebar(section: environment.state.settingsSection, select: { environment.set(.settingsSection($0)) },
                            step: { environment.set(.settingsStep($0)) })
                .frame(width: 216)
            page
                .frame(minWidth: 464, maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.craftBG.ignoresSafeArea())
                .overlay(alignment: .leading) { Rectangle().fill(Color.craftBorder).frame(width: 1).ignoresSafeArea() }
        }
        .background(Color.craftBG)
        .onBubble {
            On(.generalRole, CraftedRole.self) { preferences.set(.role($0)) }
            On(.generalCreditName, String.self) { preferences.set(.creditName($0)) }
            On(.generalCreditLink, String.self) { preferences.set(.creditLink($0)) }
            On(.generalAppearance, AppearanceChoice.self) { choice in
                preferences.set(.appearance(choice))
                CraftedAppRoot.shared.applyAppearance(choice)
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch environment.state.settingsSection {
        case .general: GeneralPage(preferences: preferences.state)
        case .models: Models()
        case .about: AboutPage(choice: CraftedRuntimeRoot.shared.modelChoice)
        }
    }
}
