import CraftedCore
import CraftedForge
import CraftedRuntime
import Granite
import SwiftUI

extension Listing {
    var view: some View {
        let draft = draft
        let problems = ListingDraft.problems(draft, role: role)
        let outcome = forge.state.exports[id]
        let report = outcome?.report ?? forge.state.live(id)?.report
        let exporting = forge.state.exporting == id
        let canDownload = problems.isEmpty && isFinished && !exporting && forge.state.live(id)?.phase.isLive != true
        return ScrollView {
            VStack(alignment: .leading, spacing: .layer4) {
                if mode == .page {
                    PageBar(title: draft.name.isEmpty ? (record?.title ?? "Listing") : draft.name,
                            subtitle: [role.title, record?.sourceName ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")) {
                        Button("Update from Folder…") { CraftedAppRoot.shared.updateFromFolder(id) }.buttonStyle(.craftQuiet)
                    }
                    PaperLeaf(cornerRadius: 12) {
                        ZStack(alignment: .topLeading) {
                            ScenePainting(scene: .gardens, progress: isFinished ? nil : (record?.fraction ?? 0), animated: true)
                            Text(draft.name).craftType(.pageTitle).foregroundStyle(WatercolourPalette.ink).padding(.layer4)
                        }
                    }
                    .frame(height: 120)
                }
                IconWell(path: library.state.icons[id], revision: library.state.iconRevision, word: draft.word,
                         targeted: state.iconTargeted)
                    .onDrop(of: [.fileURL], isTargeted: center.$state.binding.iconTargeted) { dropIcon($0) }
                ListingFields(name: center.$state.binding.name, word: center.$state.binding.word,
                              tagline: center.$state.binding.tagline, category: center.$state.binding.category,
                              keywords: center.$state.binding.keywords, platforms: center.$state.binding.platforms,
                              license: center.$state.binding.license, creditName: center.$state.binding.creditName,
                              creditLink: center.$state.binding.creditLink, role: role, problems: problems,
                              fields: saved?.fields ?? [])
                SaveRow(dirty: isDirty, saving: state.saving, savedAt: state.savedAt, problem: state.problem ?? library.state.problem)
                DownloadCard(enabled: canDownload, finished: isFinished, valid: problems.isEmpty, exporting: exporting,
                             outcome: outcome, report: report, lastExport: record?.lastExport,
                             lastExportPath: record?.lastExportPath)
            }
            .padding(mode == .page ? .layer5 : .layer4)
            .padding(.top, mode == .page ? .layer4 : 0)
            .frame(maxWidth: mode == .page ? 760 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: mode == .page ? .center : .leading)
        }
        .onAppear { load() }
        .onChange(of: saved) { _, _ in load() }
        .onChange(of: state.name) { old, new in nameChanged(from: old, to: new) }
        .onBubble {
            On(.listingSave) { Task { await save() } }
            On(.listingRevert) { load(force: true) }
            On(.listingDownload) { download() }
            On(.listingReveal, String.self) { CraftedAppRoot.shared.reveal($0) }
            On(.iconChoose) { chooseIcon() }
            On(.iconRemove) { removeIcon() }
            On(.pageBarBack) { CraftedAppRoot.shared.showLibrary() }
        }
    }
}
