//  WHAT: Downloads one of Crafted's two models into the shared home, at the commit the catalog pins, without
//        loading it.
//  IN:   A ModelSpec (repository and pinned revision); FrigateBridge's HubDownloader.
//  OUT:  ModelService's Download reducer.
//  PIN:  PER-FILE RESUME. The Hub keeps a stopped file's bytes beside it (`.incomplete`) and continues from them, so a
//        cancelled or failed download picks up where it stopped when it is started again.
//  PIN:  A CANCELLED DOWNLOAD MAY RETURN NORMALLY. The Hub's snapshot does not always throw on cancellation, so the
//        caller checks `Task.isCancelled` and reads the disk again (ModelLocator) before it says "installed".

import CraftedCore
import Foundation
import FrigateBridge

public enum ModelDownloader {
    /// What a snapshot needs to load: weights, configs, the tokenizer and the chat template. No code.
    public static let patterns = ["*.safetensors", "*.json", "*.jinja", "*.txt", "*.model", "*.tiktoken"]

    /// Downloads `spec` at its pinned revision. Answers the snapshot folder. A complete copy at that commit already in
    /// the home is answered at once without the network.
    public static func download(_ spec: ModelSpec, home: ModelHome = .standard,
                                progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try FileManager.default.createDirectory(at: home.snapshots, withIntermediateDirectories: true)
        return try await home.downloader().download(id: spec.id, revision: spec.revision, matching: patterns,
                                                    useLatest: false) { fraction in
            progress(fraction.fractionCompleted)
        }
    }
}
