import AppKit
import CraftedCore
import CraftedRuntime
import Granite
import SwiftUI
import UniformTypeIdentifiers

extension Listing {
    var saved: AgentListing? { library.state.listings[id] }
    var record: CraftedCore.Generation? { library.state.generation(id) }
    var role: CraftedRole { record?.role ?? forge.state.live(id)?.role ?? .engineer }
    var draft: AgentListing { ListingDraft.listing(state, saved: state.base ?? saved) }
    var isDirty: Bool { ListingDraft.isDirty(state) }

    /// Finished: the run is done (this launch) or the record says so.
    var isFinished: Bool {
        if let run = forge.state.live(id) { return run.phase == .done }
        return record?.status == .finished
    }

    /// The fields from what is saved: on first show, and whenever the saved listing changes while nothing is typed.
    func load(force: Bool = false) {
        guard let saved else { return }
        guard force || state.loadedFor != id || !isDirty else { return }
        var next = state
        ListingDraft.load(saved, into: &next, id: id)
        _state.wrappedValue = next
    }

    /// The word follows the name until the person edits the word.
    func nameChanged(from old: String, to new: String) {
        guard !(saved?.edited.contains(.word) ?? false) else { return }
        if state.word == AgentIdentity.derive(display: old).word || state.word.isEmpty {
            _state.word.wrappedValue = AgentIdentity.derive(display: new).word
        }
    }

    /// Save: the changed keys, onto what is on disk now, marked `edited`, written to listing.json.
    func save() async {
        guard let saved, isDirty else { return }
        _state.saving.wrappedValue = true
        let marked = ListingDraft.saving(state, onto: saved)
        do {
            let written = try await library.saveListing(marked, for: id)
            var next = state
            ListingDraft.load(written, into: &next, id: id)
            next.saving = false
            next.savedAt = Date()
            next.problem = nil
            _state.wrappedValue = next
        } catch {
            _state.saving.wrappedValue = false
            _state.problem.wrappedValue = error.localizedDescription
        }
    }

    /// Download as zip: saved first if anything is typed, then the save panel and the assembly.
    func download() {
        Task { @MainActor in
            if isDirty { await save() }
            CraftedAppRoot.shared.export(id)
        }
    }

    /// Any picture as the icon: normalised by the store to a square 1024 px PNG.
    func setIcon(_ url: URL) {
        Task { @MainActor in
            do { try await library.setIcon(from: url, for: id); _state.problem.wrappedValue = nil }
            catch { _state.problem.wrappedValue = error.localizedDescription }
        }
    }

    func chooseIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Any picture: Crafted makes it a square 1024 px PNG, cropped to the middle."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setIcon(url)
    }

    func removeIcon() {
        Task { @MainActor in try? await library.removeIcon(for: id) }
    }

    /// A picture dropped on the well.
    func dropIcon(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in setIcon(url) }
        }
        return true
    }
}
