import Network
import Foundation

/// Monitors network reachability and publishes connectivity state.
/// Uses `NWPathMonitor` on a background queue; all updates are dispatched to the main actor.
@MainActor
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "com.globedisplay.networkmonitor", qos: .utility)

    private init() {}

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
