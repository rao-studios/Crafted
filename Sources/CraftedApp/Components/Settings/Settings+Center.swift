import Granite

extension Settings {
    /// Everything a page shows is a service's; nothing is held here.
    struct Center: GraniteCenter {
        struct State: GraniteState {}

        @Store var state: State
    }
}
