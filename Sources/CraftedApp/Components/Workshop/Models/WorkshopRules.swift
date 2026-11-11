import CraftedCore
import CraftedRuntime
import Foundation

/// The page the Workshop shows.
enum WorkshopPage: Equatable {
    case home
    /// The run washing in, its stages, a question, Cancel and Resume, a failure.
    case generation(String)
    /// Engineer: three ways the project could become an agent.
    case interpretations(String)
    /// The listing form as a page, with Download.
    case listing(String)
}

/// Which page a route shows, from the live run (this launch) and the generation's record (disk).
///
/// | Route and state                                         | Page                                             |
/// |---------------------------------------------------------|--------------------------------------------------|
/// | `.library`                                              | Home                                             |
/// | `.generation(id)`, live and analysing or generating     | Generation (the Listing panel behind its button) |
/// | `.generation(id)`, live and choosing                    | Interpretations                                  |
/// | `.generation(id)`, finished                             | Listing (with Download)                          |
/// | `.generation(id)`, interrupted or failed                | Generation (Resume, the failure card)            |
enum WorkshopRules {
    static func page(_ route: Route, run: LiveRun?, record: Generation?) -> WorkshopPage {
        guard case .generation(let id) = route else { return .home }
        if let run, run.id == id {
            switch run.phase {
            case .choosing: return run.cards.isEmpty ? .generation(id) : .interpretations(id)
            case .done: return .listing(id)
            case .analysing, .generating, .failed, .cancelled: return .generation(id)
            }
        }
        if record?.status == .finished { return .listing(id) }
        return .generation(id)
    }

    /// A record that says it is running when no run is live in this process was cut off (a quit, a crash): it reads as
    /// interrupted, and Resume picks it up.
    static func shownStatus(_ record: Generation, run: LiveRun?) -> GenerationStatus {
        if let run, run.id == record.id {
            switch run.phase {
            case .analysing, .generating: return .generating
            case .choosing: return .choosing
            case .done: return .finished
            case .failed: return .failed
            case .cancelled: return .interrupted
            }
        }
        return record.status.isLive ? .interrupted : record.status
    }
}
