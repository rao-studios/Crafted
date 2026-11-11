//  WHAT: The environment's decisions as values: the writer's mutation, Settings' arrow keys, and the one disk read
//        (what a proposed folder holds).
//  OUT:  EnvironmentService's reducers; CraftedAppRoot.
//  PIN:  `apply` and `settingsStep` are pure; `count` reads the disk and nothing else.

import CraftedCore
import Foundation

enum EnvironmentOps {
    static func apply(_ kind: EnvironmentService.Set.Meta.Kind, to state: inout EnvironmentService.Center.State) {
        switch kind {
        case .activated(let active):
            state.isActive = active
        case .machine(let profile):
            state.machine = profile
        case .onboarding(let phase):
            state.onboarding = phase
        case .held(let url):
            guard !state.heldFolders.contains(url) else { return }
            state.heldFolders.append(url)
        case .heldTaken:
            state.heldFolders = []
        case .route(let route):
            state.route = route
        case .proposal(let proposal):
            state.proposal = proposal
        case .counted(let folder, let files, let images, let capped, let problem):
            guard state.proposal?.folder == folder else { return }
            state.proposal?.files = files
            state.proposal?.images = images
            state.proposal?.capped = capped
            state.proposal?.problem = problem
        case .settingsSection(let section):
            state.settingsSection = section
        case .settingsStep(let offset):
            state.settingsSection = settingsStep(from: state.settingsSection, by: offset)
        case .reset:
            state = .init()
        }
    }

    /// The arrow keys: the next or the previous page, stopping at the ends.
    static func settingsStep(from section: SettingsSection, by offset: Int) -> SettingsSection {
        let ordered = SettingsSection.ordered
        guard let index = ordered.firstIndex(of: section) else { return section }
        return ordered[max(0, min(ordered.count - 1, index + offset))]
    }

    // MARK: - A proposed folder

    static let imageExtensions: Swift.Set<String> = ["png", "jpg", "jpeg", "webp", "heic", "heif", "tif", "tiff", "gif",
                                                     "bmp", "psd", "svg", "pdf", "ai"]
    /// Never walked: build output, dependencies, version control.
    static let skippedFolders: Swift.Set<String> = [".git", ".build", ".swiftpm", "node_modules", "DerivedData", ".venv",
                                                    "venv", "__pycache__", "Pods", ".idea", ".gradle", "build", "dist"]
    static let cap = 50_000

    struct Count: Equatable {
        var files: Int?
        var images: Int?
        var capped = false
        var problem: String?
    }

    /// Every file under `folder` the forge would see, and the pictures among them, up to `cap`.
    static func count(_ folder: URL) -> Count {
        let fm = FileManager.default
        var isFolder: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isFolder), isFolder.boolValue else {
            return Count(problem: "\(folder.lastPathComponent) is not a folder Crafted can read.")
        }
        guard let walker = fm.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                         options: [.skipsPackageDescendants]) else {
            return Count(problem: "\(folder.lastPathComponent) could not be read.")
        }
        var files = 0
        var images = 0
        for case let url as URL in walker {
            let name = url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                if skippedFolders.contains(name) { walker.skipDescendants() }
                continue
            }
            if name == ".DS_Store" { continue }
            files += 1
            if imageExtensions.contains(url.pathExtension.lowercased()) { images += 1 }
            if files >= cap { return Count(files: files, images: images, capped: true) }
        }
        return Count(files: files, images: images)
    }
}
