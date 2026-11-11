import SwiftUI

/// A page: its title and what it is for, then its cards, at a reading measure. A page with a control of its own
/// (Models' rescan) sets it beside the title.
struct SettingsPage<Content: View, Accessory: View>: View {
    let section: SettingsSection
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(section: SettingsSection, @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.section = section
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .layer4) {
                VStack(alignment: .leading, spacing: .layer1) {
                    HStack(alignment: .firstTextBaseline, spacing: .layer3) {
                        Text(section.title)
                            .craftType(.pageTitle)
                            .foregroundStyle(Color.craftInk)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: .layer3)
                        accessory
                    }
                    Text(section.subtitle)
                        .craftType(.label)
                        .foregroundStyle(Color.craftInkDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, .layer1)
                content
            }
            .frame(maxWidth: CraftLayout.settingsMeasure, alignment: .leading)
            .padding(.layer5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension SettingsPage where Accessory == EmptyView {
    init(section: SettingsSection, @ViewBuilder content: () -> Content) {
        self.init(section: section, accessory: { EmptyView() }, content: content)
    }
}
