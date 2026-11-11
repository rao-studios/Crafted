import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Dropped files and folders become a proposed generation (Home's confirmation card): a file proposes its folder.
enum FolderDrop {
    static let types: [UTType] = [.fileURL]

    @discardableResult
    static func open(_ providers: [NSItemProvider]) -> Bool {
        folders(providers) { CraftedAppRoot.shared.propose($0) }
    }

    /// Each dropped item's folder, delivered on the main actor.
    @discardableResult
    static func folders(_ providers: [NSItemProvider], then: @escaping @MainActor (URL) -> Void) -> Bool {
        let candidates = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !candidates.isEmpty else { return false }
        for provider in candidates {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                let folder = isDirectory.boolValue ? url : url.deletingLastPathComponent()
                Task { @MainActor in then(folder) }
            }
        }
        return true
    }
}
