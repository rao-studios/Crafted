import SwiftUI

/// One page in the sidebar: its symbol and its name, drawn as every sidebar row is (`SidebarRow`).
struct SettingsSidebarRow: View {
    let section: SettingsSection
    let selected: Bool
    let select: () -> Void

    var body: some View {
        SidebarRow(symbol: section.symbol, title: section.sidebarTitle, selected: selected,
                   identifier: "settings.sidebar.\(section.rawValue)", select: select)
    }
}
