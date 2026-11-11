import Granite
import SwiftUI

/// The top of a generation's page: back to the library, its name and what it is, and the page's actions.
struct PageBar<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        HStack(alignment: .center, spacing: .layer3) {
            Button { back() } label: {
                HStack(spacing: .layer1) {
                    Image(systemName: "chevron.left").font(.craftGlyph(.caption, weight: .semibold))
                    Text("Library").craftType(.label)
                }
            }
            .buttonStyle(.craftQuiet)
            .keyboardShortcut("[", modifiers: .command)
            VStack(alignment: .leading, spacing: .hairline) {
                Text(title).craftType(.pageTitle).foregroundStyle(Color.craftInk).lineLimit(1).truncationMode(.tail)
                if !subtitle.isEmpty {
                    Text(subtitle).craftType(.caption).foregroundStyle(Color.craftInkDim).lineLimit(1)
                }
            }
            Spacer(minLength: .layer3)
            actions
        }
    }

    private func back() { bubble(.pageBarBack) }
}

extension GraniteBubble.Name {
    static let pageBarBack: Self = "PageBar.back"
}
