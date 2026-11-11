import Foundation

/// What the Workshop window shows: the library (Home), or one generation (its run, its interpretations or its
/// listing, by where it stands).
enum Route: Equatable, Sendable, Hashable {
    case library
    case generation(String)

    var generationID: String? {
        if case .generation(let id) = self { return id }
        return nil
    }
}

/// A folder dropped on Home or on the Dock icon, waiting for the confirmation card's Start.
struct FolderProposal: Equatable, Sendable {
    var folder: URL
    /// What it holds, once counted (`Inspect`): every file, and the pictures among them.
    var files: Int?
    var images: Int?
    /// The count stopped at its cap: "more than".
    var capped = false
    /// The folder could not be read.
    var problem: String?

    init(folder: URL) { self.folder = folder }

    var name: String { folder.lastPathComponent }
}
