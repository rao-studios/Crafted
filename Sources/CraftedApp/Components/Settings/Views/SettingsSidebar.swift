import SwiftUI

/// The pages, in their groups, from under the traffic lights; ↑ and ↓ walk them. The last group
/// stands apart at the foot of the window, under a rule of its own.
struct SettingsSidebar: View {
    let section: SettingsSection
    let select: (SettingsSection) -> Void
    /// The arrow keys: a page on, or back.
    let step: (Int) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: .layer4) {
                    ForEach(Array(SettingsSection.groups.dropLast().enumerated()), id: \.offset) { index, group in
                        // The groups are told apart by a rule, as `SettingsSection.groups` says.
                        if index > 0 { rule }
                        rows(group)
                    }
                }
                .padding(.horizontal, .layer3)
                .padding(.vertical, .layer2)
            }
            // The same rule and spacing as between the groups above, with a margin under the last row.
            VStack(alignment: .leading, spacing: .layer4) {
                rule
                rows(SettingsSection.groups.last ?? [])
            }
            .padding(.horizontal, .layer3)
            .padding(.top, .layer2)
            .padding(.bottom, .layer3)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onMoveCommand { direction in
            switch direction {
            case .up: step(-1)
            case .down: step(1)
            default: break
            }
        }
        .defaultFocus($focused, true)
        .accessibilityElement(children: .contain)
        .background(Color.craftBG.ignoresSafeArea())
    }

    private var rule: some View {
        Divider().overlay(Color.craftBorder).padding(.horizontal, .layer2)
    }

    private func rows(_ group: [SettingsSection]) -> some View {
        VStack(spacing: .hairline) {
            ForEach(group) { section in
                SettingsSidebarRow(section: section, selected: self.section == section) {
                    select(section)
                    focused = true
                }
            }
        }
    }
}
