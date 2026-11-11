//  WHAT: The listing form: the agent's icon, name, word, tagline, category, keywords, platforms, licence and credit,
//        its fields (read-only), the store's rules inline, Save, and Download as zip. One component: a panel over a
//        live run, and the page of a finished generation.
//  IN:   LibraryService (the saved listing.json and icon.png), ForgeService (the run, the download's result),
//        the generation's record (its role, whether it is finished).
//  OUT:  LibraryService (save the listing, set or clear the icon), CraftedAppRoot (Download: the save panel, then
//        ForgeService.export).
//  PIN:  THE PERSON'S WORDS WIN. Save marks every changed key `edited`; the forge's later suggestions fill only the
//        keys not in it. Nothing is lost if the app quits: Save writes listing.json at once.
//  PIN:  DOWNLOAD IS ASSEMBLY. It rebuilds the package from the saved name, word, licence, icon and listing, so editing
//        later and downloading again is the same button. It stays off until the form is valid and the run is done.
//  PIN:  The store checks a word's uniqueness when the repository is listed; the form says so.

import CraftedCore
import CraftedForge
import CraftedRuntime
import Granite
import SwiftUI

struct Listing: GraniteComponent {
    @Command var center: Center
    @Relay var library: LibraryService
    @Relay var forge: ForgeService

    /// A save landing, the forge's suggestion arriving and a download's result show at once.
    @StateObject var clock = RelayClock([.on(LibraryService.self), .on(ForgeService.self)])

    let id: String
    let mode: ListingMode

    init(id: String, mode: ListingMode) {
        self.id = id
        self.mode = mode
    }
}

extension Listing {
    /// The fields as the person types them; what is saved is the library's.
    struct Center: GraniteCenter {
        struct State: GraniteState {
            /// The generation the fields were loaded for, and the listing they were loaded from: what "changed" means.
            var loadedFor: String?
            var base: AgentListing?
            var name = ""
            var word = ""
            var tagline = ""
            var category: ListingCategory = .utilities
            /// Comma-separated.
            var keywords = ""
            var platforms = ""
            var license: ListingLicence = .mit
            var creditName = ""
            var creditLink = ""
            var saving = false
            var savedAt: Date?
            var problem: String?
            /// A picture is being dragged over the icon well.
            var iconTargeted = false
        }

        @Store var state: State
    }
}
