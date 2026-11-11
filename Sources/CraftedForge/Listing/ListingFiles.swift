//  WHAT: The files a listing puts in a package: Assets/listing.json, Assets/icon.png (the person's, or a painted
//        default), and LICENSE in the licence they chose, with the year and the copyright holder.
//  IN:   The listing as saved, the generation's icon (nil when the person gave none), the identity.
//  OUT:  Forge.assemble, after the pipeline's own assembly; the store validator then reads them as the store will.
//  PIN:  THE STORE'S ICON, ALWAYS. Whatever is written is a square PNG of 512 px or more and 6 MB at most: a
//        person's picture that is not one is normalised to a 1024 px square first.
//  PIN:  ONE LICENCE FILE. LICENSE is written whole; LICENSE.md, LICENSE.txt, LICENCE and LICENCE.md a template may
//        carry are removed, so the store and a reader see one licence.

import CraftedCore
import Foundation

public enum ListingFiles {
    public static func write(listing: AgentListing, icon: URL?, identity: AgentIdentity, role: CraftedRole, into package: URL) throws {
        let assets = package.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try AtomicFile.write(try listing.storeJSON(), to: assets.appendingPathComponent("listing.json"))
        try AtomicFile.write(try iconPNG(icon, identity: identity), to: assets.appendingPathComponent("icon.png"))
        try writeLicence(listing.license, holder: LicenceText.holder(for: listing), into: package)
    }

    /// The person's icon as the store takes it, or the painted default.
    public static func iconPNG(_ icon: URL?, identity: AgentIdentity) throws -> Data {
        guard let icon else { return try DefaultIcon.png(for: identity) }
        let data = try Data(contentsOf: icon)
        if IconCheck.problems(data).isEmpty { return data }
        let normalised = try IconNormaliser.squarePNG(from: icon, side: DefaultIcon.side)
        if let problem = IconCheck.problems(normalised).first { throw ForgeError.gate(problem) }
        return normalised
    }

    public static func writeLicence(_ licence: ListingLicence, holder: String, year: Int = LicenceText.currentYear, into package: URL) throws {
        let text = try LicenceText.text(licence, holder: holder, year: year)
        for other in LicenceRecogniser.files where other != "LICENSE" {
            try? FileManager.default.removeItem(at: package.appendingPathComponent(other))
        }
        try AtomicFile.write(text, to: package.appendingPathComponent("LICENSE"))
    }
}
