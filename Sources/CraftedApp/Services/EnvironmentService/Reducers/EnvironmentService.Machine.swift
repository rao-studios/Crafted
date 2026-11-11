import CraftedCore
import Foundation
import Granite
import GraniteAgents

extension EnvironmentService {
    /// This Mac, read once: the first ask reads the chip, the memory and Metal's working set off the main thread and
    /// keeps them; every later ask is answered from the state.
    ///
    /// PIN: READ, NOTHING STARTED. `DeviceProfile.read` asks Metal for its device's numbers, never for a queue, and MLX
    /// is not touched: knowing the Mac never touches the GPU.
    struct Machine: GraniteReducer {
        typealias Center = EnvironmentService.Center
        init() {}

        struct Meta: GranitePayload {
            var ticket: UUID?
            init(ticket: UUID?) { self.ticket = ticket }
        }

        @Payload var meta: Meta?

        func effect(state: Center.State) -> GraniteEffect {
            let ticket = meta?.ticket
            if let known = state.machine {
                return .run { if let ticket { await EnvironmentService.tickets.resolve(ticket, with: known) } }
            }
            let environment = Live.service(EnvironmentService.self)
            return .run {
                let profile = DeviceProfile.read()
                environment.set(.machine(profile))
                if let ticket { await EnvironmentService.tickets.resolve(ticket, with: profile) }
            }
        }

        var thread: DispatchQueue? { .main }
    }
}
