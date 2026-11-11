//  WHAT: The files a listing puts in a package: Assets/listing.json, Assets/icon.png (the person's, or a painted
//        default), and LICENSE in the licence they chose.
//  OUT:  Forge.assemble, after the pipeline's own assembly.
//  TODO(forge-gates track): the painted default icon and the licence texts. This writes the listing and copies the icon.

import CraftedCore
import Foundation

public enum ListingFiles {
    public static func write(listing: AgentListing, icon: URL?, identity: AgentIdentity, role: CraftedRole, into package: URL) throws {
        let assets = package.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try AtomicFile.write(try listing.storeJSON(), to: assets.appendingPathComponent("listing.json"))
        if let icon {
            try AtomicFile.write(try Data(contentsOf: icon), to: assets.appendingPathComponent("icon.png"))
        }
    }
}
