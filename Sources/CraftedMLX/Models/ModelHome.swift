//  WHAT: Where models live on this Mac: the shared home every Rao app downloads into and reads from, so the copies
//        Craft fetched are found here and nothing is downloaded twice.
//  IN:   AII_HOME (an absolute path) when set, else ~/.rao under the password database's home.
//  OUT:  ModelLocator, ModelDownloader, ModelRemover, the runtime's load.
//  PIN:  THE SAME RULE AS CRAFT'S ModelHome (Craft/Sources/CraftMLX/Models/ModelHome.swift): AII_HOME/models/huggingface
//        is the HF_HOME every Rao server and app shares. A model sits at
//        <home>/snapshots/models/<org>/<name>, exactly where Craft's onboarding put it.

import CraftedCore
import Foundation
import FrigateBridge

public struct ModelHome: Sendable, Equatable {
    /// `AII_HOME/models/huggingface`.
    public var huggingFace: URL

    public init(huggingFace: URL) {
        self.huggingFace = huggingFace
    }

    public static var standard: ModelHome { resolved() }

    public static func resolved(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> ModelHome {
        let user: URL
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            user = URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        } else {
            user = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        }
        var root = user.appendingPathComponent(".rao", isDirectory: true)
        if let raw = environment["AII_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), raw.hasPrefix("/") {
            root = URL(fileURLWithPath: raw, isDirectory: true)
        }
        return ModelHome(huggingFace: root.appendingPathComponent("models/huggingface", isDirectory: true))
    }

    /// `<home>/snapshots`: the Hub's download base.
    public var snapshots: URL { huggingFace.appendingPathComponent("snapshots", isDirectory: true) }
    /// `<home>/snapshots/models`.
    public var modelsRoot: URL { snapshots.appendingPathComponent("models", isDirectory: true) }

    /// Where `spec` downloads to: `<home>/snapshots/models/<org>/<name>`.
    public func folder(_ spec: ModelSpec) -> URL {
        modelsRoot.appendingPathComponent(spec.organisation, isDirectory: true)
            .appendingPathComponent(spec.folderName, isDirectory: true)
    }

    /// Where a complete copy is looked for: this home's own roots, then the Rao stack's when AII_HOME moved it.
    public var lookupRoots: [URL] { HubDownloader.snapshotRoots(home: huggingFace) }

    /// The only roots a copy is ever deleted from.
    public var ownRoots: [URL] { HubDownloader.ownRoots(home: huggingFace) }

    /// Downloads into, and reads from, this home only: never ~/.cache or ~/Documents.
    func downloader() -> HubDownloader {
        HubDownloader(home: huggingFace)
    }
}
