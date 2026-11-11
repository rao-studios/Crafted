import CraftedCore
import Foundation

/// NOTICE: where the agent came from, under which licence the source is, and what the person must keep with it.
enum NoticeWriter {
    static func text(identity: AgentIdentity, listing: AgentListing, project: ProjectRecord) -> String {
        var lines = ["\(identity.display)", "This agent was made by Crafted from the project \(project.title) (`\(project.folder)`). Its logic is a port of that project's code to Swift."]
        if let licence = project.licence {
            lines.append("The source project is licensed \(licence); the port keeps its notices." + (ListingLicence(rawValue: licence)?.isCopyleft == true ? " Its licence is copyleft, so this agent is \(licence) too." : ""))
        } else {
            lines.append("The source project states no licence Crafted recognises: make sure you may publish a port of it before you list this agent.")
        }
        lines.append("This package is licensed \(listing.license.rawValue): see LICENSE.")
        lines.append("The package's frame (the agent wiring, router, emitters and report kit) is Crafted's EngineerAgentSkeleton, MIT licensed.")
        return lines.joined(separator: "\n\n") + "\n"
    }
}
