//  WHAT: The full text of a listing's licence, with the year and the copyright holder: what LICENSE says in a
//        generated package.
//  IN:   Resources/Licences/<SPDX>.txt, found through ForgeResources. Each is the canonical text taken from disk, not
//        from memory (2026-11-10): MIT and ISC as npm packages ship them (react-dom, picocolors), BSD-2-Clause from the
//        Rust toolchain's SPDX copy (BSD-3-Clause adds SPDX's third clause to it), Apache-2.0 as the Rao model
//        snapshots carry it, MPL-2.0 as satori ships it, GPL-3.0 as Crafted's own LICENSE. `{{year}}` and
//        `{{holder}}` mark the copyright line.
//  OUT:  ListingFiles (LICENSE), the store validator's recognised-licence rule.
//  PIN:  THE STORE MUST RECOGNISE IT. The BSD texts carry their "BSD n-Clause License" title and ISC its "ISC
//        License" title, because the store's check reads the title (sources.ts `licenseIn`); the long texts sit under
//        one copyright line, well inside the 600 characters it reads.

import CraftedCore
import Foundation

public enum LicenceText {
    /// The text of `licence` for `holder` in `year`.
    public static func text(_ licence: ListingLicence, holder: String, year: Int) throws -> String {
        guard let template = ForgeResources.text("Licences/\(licence.rawValue).txt") else {
            throw ForgeError.notFound("The \(licence.rawValue) licence text (Resources/Licences/\(licence.rawValue).txt)")
        }
        let name = holder.trimmingCharacters(in: .whitespacesAndNewlines)
        return template
            .replacingOccurrences(of: "{{year}}", with: String(year))
            .replacingOccurrences(of: "{{holder}}", with: name.isEmpty ? "The authors" : name)
    }

    /// Who holds the copyright: the credited designer, else the agent's name.
    public static func holder(for listing: AgentListing) -> String {
        let designer = listing.credit?.designer.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return designer.isEmpty ? listing.name : designer
    }

    public static var currentYear: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }
}
