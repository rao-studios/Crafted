import AppKit
import CraftedCore
import CraftedForge
import CraftedRuntime
import Granite
import SwiftUI

/// The agent's icon: the picture the person gave (or its word's first letter until they do), with Choose and Remove;
/// a picture dropped on it is taken too.
struct IconWell: View {
    let path: String?
    let revision: Int
    let word: String
    let targeted: Bool
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        HStack(alignment: .center, spacing: .layer4) {
            TileIcon(path: path, revision: revision, word: word.isEmpty ? "a" : word, painting: nil, size: CraftLayout.iconWell)
                .overlay {
                    if targeted {
                        StitchedOutline(cornerRadius: CraftRadius.control, spacing: 7, dotRadius: 1.4, color: WatercolourPalette.brass)
                    }
                }
            VStack(alignment: .leading, spacing: .layer2) {
                SectionLabel("Icon")
                Text("Any picture, dropped here or chosen: it becomes a square 1024 px PNG, cropped to the middle.")
                    .craftType(.caption).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: .layer2) {
                    Button("Choose…") { choose() }.buttonStyle(.craftQuiet)
                    if path != nil { Button("Remove") { remove() }.buttonStyle(.craftQuiet) }
                }
                if path == nil {
                    Text("Without one, the agent ships a painted default.").craftType(.caption).foregroundStyle(Color.craftInkDim)
                }
            }
        }
    }

    private func choose() { bubble(.iconChoose) }
    private func remove() { bubble(.iconRemove) }
}

/// The listing's fields per the store's table, each with its rule's sentence beneath when it is broken.
struct ListingFields: View {
    @Binding var name: String
    @Binding var word: String
    @Binding var tagline: String
    @Binding var category: ListingCategory
    @Binding var keywords: String
    @Binding var platforms: String
    @Binding var license: ListingLicence
    @Binding var creditName: String
    @Binding var creditLink: String
    let role: CraftedRole
    let problems: [ListingKey: [String]]
    let fields: [ListingField]

    var body: some View {
        VStack(alignment: .leading, spacing: .layer3) {
            field("Name", key: .name, note: "\(name.count) of \(ListingRules.nameLimit)") {
                CraftTextField(placeholder: "What the store shows", text: $name)
            }
            field("Word", key: .word, note: "What Craft calls it by: lowercase letters and digits. The store checks it is free when you list the repository.") {
                CraftTextField(placeholder: "word", text: $word, role: .code)
            }
            field("Tagline", key: .tagline, note: "\(tagline.count) of \(ListingRules.taglineLimit)") {
                CraftTextField(placeholder: "What it makes, in a line", text: $tagline)
            }
            HStack(alignment: .top, spacing: .layer4) {
                field("Category", key: .category, note: nil) {
                    Picker("Category", selection: $category) {
                        ForEach(ListingCategory.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
                field("Licence", key: .license, note: nil) {
                    Picker("Licence", selection: $license) {
                        ForEach(ListingLicence.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
            }
            field("Keywords", key: .keywords, note: "Up to \(ListingRules.keywordLimit), separated by commas.") {
                CraftTextField(placeholder: "poster, brochure, swiss", text: $keywords)
            }
            field("Platforms", key: .platforms, note: "1 to \(ListingRules.platformLimit), separated by commas.") {
                CraftTextField(placeholder: "macOS 26", text: $platforms)
            }
            field(role == .designer ? "Credit (required)" : "Credit", key: .credit,
                  note: role == .designer ? "The designer whose style it is: named in the listing, README, NOTICE and every piece." : nil) {
                VStack(spacing: .layer2) {
                    CraftTextField(placeholder: "Name", text: $creditName)
                    CraftTextField(placeholder: "https://… (optional)", text: $creditLink, content: .URL)
                }
            }
            if !fields.isEmpty {
                VStack(alignment: .leading, spacing: .layer1) {
                    SectionLabel("Fields")
                    Text("The agent's inputs, as the store shows them. They come from the agent.")
                        .craftType(.caption).foregroundStyle(Color.craftInkDim)
                    ForEach(fields, id: \.self) { field in
                        HStack(alignment: .firstTextBaseline, spacing: .layer2) {
                            Text(field.name + (field.required ? "" : "?")).craftType(.identifier).foregroundStyle(Color.craftInk)
                            Text(field.type).craftType(.codeSmall).foregroundStyle(Color.craftInkDim)
                            Text(field.note).craftType(.caption).foregroundStyle(Color.craftInkSoft).lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    private func field<Content: View>(_ title: String, key: ListingKey, note: String?, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: .layer1) {
            SectionLabel(title)
            content()
            if let messages = problems[key] {
                ForEach(messages, id: \.self) { message in
                    Text(message).craftType(.caption).foregroundStyle(Color.craftError).fixedSize(horizontal: false, vertical: true)
                }
            } else if let note {
                Text(note).craftType(.fine).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Save, and whether there is anything to save.
struct SaveRow: View {
    let dirty: Bool
    let saving: Bool
    let savedAt: Date?
    let problem: String?
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        VStack(alignment: .leading, spacing: .layer1) {
            HStack(spacing: .layer2) {
                Button(saving ? "Saving…" : "Save") { save() }
                    .buttonStyle(.craft)
                    .disabled(!dirty || saving)
                    .keyboardShortcut("s", modifiers: .command)
                    .accessibilityIdentifier("listing.save")
                if dirty { Button("Revert") { revert() }.buttonStyle(.craftQuiet) }
                Text(dirty ? "Not saved yet." : savedAt.map { "Saved " + CraftFormat.ago($0) + "." } ?? "Saved.")
                    .craftType(.caption).foregroundStyle(Color.craftInkDim)
            }
            if let problem {
                Text(problem).craftType(.caption).foregroundStyle(Color.craftError).textSelection(.enabled)
            }
        }
    }

    private func save() { bubble(.listingSave) }
    private func revert() { bubble(.listingRevert) }
}

/// Download as zip: on once the form is valid and the run is done. The package is assembled again from what is saved,
/// checked, and zipped; the checks and where the archive went show here.
struct DownloadCard: View {
    let enabled: Bool
    let finished: Bool
    let valid: Bool
    let exporting: Bool
    let outcome: ExportOutcome?
    let report: PackageReport?
    let lastExport: Date?
    let lastExportPath: String?
    @Environment(\.graniteBubble) private var bubble

    var body: some View {
        CraftCard {
            VStack(alignment: .leading, spacing: .layer3) {
                HStack(spacing: .layer2) {
                    Button(exporting ? "Preparing…" : "Download as zip") { download() }
                        .buttonStyle(.craft)
                        .disabled(!enabled)
                        .accessibilityIdentifier("listing.download")
                    if exporting { ProgressView().controlSize(.small) }
                    Spacer()
                }
                Text(hint).craftType(.caption).foregroundStyle(Color.craftInkDim).fixedSize(horizontal: false, vertical: true)
                if let failure = outcome?.failure {
                    Text(failure).craftType(.caption).foregroundStyle(Color.craftError)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
                if let archive = outcome?.archive ?? lastExportPath {
                    HStack(spacing: .layer2) {
                        FieldRow(label: outcome?.archive != nil ? "Saved to" : "Last download", value: CraftFormat.tilde(archive))
                        Button("Show in Finder") { reveal(archive) }.buttonStyle(.craftLink).craftType(.caption)
                    }
                }
                if let report {
                    FlowLayout(spacing: .layer5, lineSpacing: .layer3) {
                        CraftStat(value: report.identity.package, label: "Package")
                        CraftStat(value: "@" + report.identity.word, label: "Word")
                        CraftStat(value: report.fileCount.formatted(), label: "Files")
                        CraftStat(value: report.built ? "Built here" : "Not built here", label: "Build")
                    }
                    GateList(gates: report.gates)
                    if !report.verification.isEmpty {
                        VStack(alignment: .leading, spacing: .hairline) {
                            SectionLabel("Verified")
                            ForEach(report.verification, id: \.self) { line in
                                Text(line).craftType(.caption).foregroundStyle(Color.craftInkSoft)
                            }
                        }
                    }
                }
            }
        }
    }

    private var hint: String {
        if exporting { return "Assembling the package with this listing and icon, checking it, and zipping it." }
        if !finished { return "Download opens when the generation finishes; what you save here goes into it." }
        if !valid { return "Fix what is marked above to download." }
        if let lastExport { return "Downloaded " + CraftFormat.ago(lastExport) + ". Downloading again rebuilds it from what is saved now." }
        return "A ready-to-push repository: unzip it and push it to GitHub to list it in Craft's store."
    }

    private func download() { bubble(.listingDownload) }
    private func reveal(_ path: String) { bubble(.listingReveal, path) }
}

extension GraniteBubble.Name {
    static let listingSave: Self = "SaveRow.save"
    static let listingRevert: Self = "SaveRow.revert"
    static let listingDownload: Self = "DownloadCard.download"
    static let listingReveal: Self = "DownloadCard.reveal"
    static let iconChoose: Self = "IconWell.choose"
    static let iconRemove: Self = "IconWell.remove"
}
