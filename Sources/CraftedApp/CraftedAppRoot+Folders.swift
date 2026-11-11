import AppKit
import CraftedCore
import CraftedForge
import CraftedRuntime
import Foundation
import UniformTypeIdentifiers

/// Folders in and archives out: a drop proposed and started, a generation updated from its folder, shown in Finder,
/// deleted, resumed, and downloaded as a zip. Each is the AppKit part (a panel, the Finder) around a service call.
extension CraftedAppRoot {
    // MARK: - A folder in

    /// Folders opened on the Dock icon or from Finder: the first one is proposed (one generation at a time); before
    /// the gate opens, they wait.
    func open(_ urls: [URL]) {
        let folders = urls.map { url -> URL in
            var isFolder: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder)
            return isFolder.boolValue ? url : url.deletingLastPathComponent()
        }
        guard environment.state.onboarding == .open else {
            folders.forEach { environment.set(.held($0)) }
            if environment.state.onboarding == .locked { show(.onboarding) }
            return
        }
        if let first = folders.first { propose(first) }
    }

    /// File › New Generation…: a folder chosen, then proposed.
    func chooseFolder() {
        guard !holdsBack() else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = preferences.state.role?.dropPrompt ?? "Choose a folder"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        propose(folder)
    }

    /// A folder dropped: Home's confirmation card (what it holds, as which role, Start), on the library.
    func propose(_ folder: URL) {
        guard !holdsBack() else {
            environment.set(.held(folder))
            return
        }
        environment.set(.proposal(FolderProposal(folder: folder.standardizedFileURL)))
        environment.inspect(folder.standardizedFileURL)
        showLibrary()
    }

    func dismissProposal() { environment.set(.proposal(nil)) }

    /// The card's Start: a new generation, as the role chosen now, and its page.
    func startProposal() {
        guard let proposal = environment.state.proposal, let role = preferences.state.role else { return }
        let forge = forge, environment = environment, options = runOptions()
        Task { @MainActor in
            do {
                let id = try await forge.start(folder: proposal.folder, role: role, options: options)
                environment.set(.proposal(nil))
                self.open(generation: id)
            } catch {
                forge.set(.problem(error.localizedDescription))
            }
        }
    }

    // MARK: - A generation

    /// Picks up an interrupted or failed run from its ledger.
    func resume(_ id: String) {
        let forge = forge, options = runOptions()
        Task { @MainActor in
            do { _ = try await forge.resume(id, options: options) } catch { forge.set(.problem(error.localizedDescription)) }
        }
        open(generation: id)
    }

    func cancel(_ id: String) { forge.cancel(id) }

    /// The tile's Update from Folder…: the project again (changed), as the folder chosen; unchanged files are not read.
    func updateFromFolder(_ id: String) {
        guard let generation = library.state.generation(id) else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = generation.sourceURL.deletingLastPathComponent()
        panel.prompt = "Update"
        panel.message = "Choose the folder \(generation.title) was made from, as it is now."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let forge = forge, options = runOptions()
        Task { @MainActor in
            do { _ = try await forge.update(id, from: folder, options: options) } catch { forge.set(.problem(error.localizedDescription)) }
        }
        open(generation: id)
    }

    func showInFinder(_ id: String) {
        let folder = LibraryService.store.folder(id)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// Deletes a generation (the page's dialog asked first). Back to the library when it was open.
    func delete(_ id: String) {
        let library = library, environment = environment
        Task { @MainActor in
            do {
                try await library.delete(id)
                if environment.state.route == .generation(id) { environment.set(.route(.library)) }
            } catch {
                library.set(.problem(error.localizedDescription))
            }
        }
    }

    // MARK: - An archive out

    /// Download as zip: where to save `<Package>.zip`, then assemble, check and zip. Nil when the person cancelled.
    func export(_ id: String) {
        guard let listing = library.state.listings[id] else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = listing.identity.package + ".zip"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.message = "The archive is a ready-to-push repository: unzip it, then push it to GitHub to list it."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let forge = forge, options = runOptions()
        Task { @MainActor in
            _ = try? await forge.export(id, to: url, options: options)
        }
    }
}
