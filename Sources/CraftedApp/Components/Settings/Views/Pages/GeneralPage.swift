//  WHAT: Settings › General: what belongs to the person rather than one generation: their role, the name (and link) a
//        designer agent credits, and how Crafted looks.
//  IN:   PreferencesService's state (Settings hands it in).
//  OUT:  `.generalRole`, `.generalCreditName`, `.generalCreditLink`, `.generalAppearance`, routed by Settings.

import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI

struct GeneralPage: View {
    let preferences: PreferencesService.Center.State

    var body: some View {
        SettingsPage(section: .general) {
            RoleCard(role: preferences.role)
            CreditCard(name: preferences.creditName, link: preferences.creditLink)
            AppearanceCard(appearance: preferences.appearance)
        }
    }
}

extension GraniteBubble.Name {
    static let generalRole: Self = "GeneralPage.role"
    static let generalCreditName: Self = "GeneralPage.creditName"
    static let generalCreditLink: Self = "GeneralPage.creditLink"
    static let generalAppearance: Self = "GeneralPage.appearance"
}

/// Designer or engineer: what the next folder dropped becomes. A run already going keeps the role it started with.
struct RoleCard: View {
    let role: CraftedRole?
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        CraftCard {
            VStack(alignment: .leading, spacing: .layer3) {
                SectionLabel("Role")
                Picker("Role", selection: Binding(get: { role ?? .designer }, set: { choose($0) })) {
                    ForEach(CraftedRole.allCases) { role in Text(role.title).tag(role) }
                }
                .pickerStyle(.segmented).labelsHidden()
                Text((role ?? .designer).blurb).settingsCaption()
                Text("The role is fixed for a generation when it starts; this changes the next folder you drop.").settingsCaption()
            }
        }
    }

    private func choose(_ role: CraftedRole) { bubble(.generalRole, role) }
}

/// The name a designer agent credits in its listing, README, NOTICE and every piece it makes, and where it links.
struct CreditCard: View {
    let name: String
    let link: String
    @Environment(\.graniteBubble) private var bubble
    @State private var nameDraft = ""
    @State private var linkDraft = ""

    var body: some View {
        CraftCard {
            VStack(alignment: .leading, spacing: .layer3) {
                SectionLabel("Credit")
                CraftTextField(placeholder: "Your name", text: $nameDraft)
                    .onSubmit { saveName() }
                CraftTextField(placeholder: "https://your.site (optional)", text: $linkDraft, content: .URL)
                    .onSubmit { saveLink() }
                Text("A designer's agent credits you by this name, and links here. Each generation's listing can change it.")
                    .settingsCaption()
            }
        }
        .onAppear { nameDraft = name; linkDraft = link }
        .onChange(of: nameDraft) { _, _ in saveName() }
        .onChange(of: linkDraft) { _, _ in saveLink() }
    }

    private func saveName() { if nameDraft != name { bubble(.generalCreditName, nameDraft) } }
    private func saveLink() { if linkDraft != link { bubble(.generalCreditLink, linkDraft) } }
}

/// How Crafted looks: as macOS does, on cream paper, or on graphite. Every window changes the moment the choice does;
/// the paintings stay on paper either way.
struct AppearanceCard: View {
    let appearance: AppearanceChoice
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        CraftCard {
            VStack(alignment: .leading, spacing: .layer3) {
                SectionLabel("Appearance")
                Picker("Appearance", selection: Binding(get: { appearance }, set: { choose($0) })) {
                    ForEach(AppearanceChoice.allCases, id: \.self) { choice in Text(choice.title).tag(choice) }
                }
                .pickerStyle(.segmented).labelsHidden()
                .accessibilityIdentifier("settings.general.appearance")
                Text(caption).settingsCaption()
            }
        }
    }

    private func choose(_ choice: AppearanceChoice) { bubble(.generalAppearance, choice) }

    private var caption: String {
        switch appearance {
        case .system: return "Follows macOS: cream paper in Light Mode, graphite in Dark Mode."
        case .light: return "Crafted on cream paper, whatever macOS is set to."
        case .dark: return "Crafted on graphite, whatever macOS is set to. The paintings stay on their paper."
        }
    }
}
