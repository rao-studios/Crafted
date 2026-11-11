//  WHAT: The one way a view keeps up with the services it reads: a clock that ticks on each
//        service's own change signal.
//  IN:   The live services' relay containers, by type.
//  OUT:  `objectWillChange` on the view that holds the clock as a `@StateObject`.
//  PIN:  A relay's holder hears a change 0.2 s after it settles (Granite's shared container
//        debounces), which a download's progress, a sign-in landing or a project just opened cannot
//        wait for. Held as a `@StateObject`, the clock invalidates the view on every signal; the
//        view still reads the service's state, never a copy kept here.

import Combine
import Granite
import SwiftUI

@MainActor
final class RelayClock: ObservableObject {
    /// One service's change signal; `.on(XService.self)` reads as the list a view hands the clock.
    struct Signal {
        let publisher: AnyPublisher<Void, Never>

        /// The change signal of `type`'s live service.
        @MainActor static func on<S: GraniteService>(_ type: S.Type) -> Signal {
            Signal(publisher: Relay<S>().relay.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        }
    }

    private var bag = Set<AnyCancellable>()

    init(_ signals: [Signal]) {
        Publishers.MergeMany(signals.map(\.publisher))
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }
}
