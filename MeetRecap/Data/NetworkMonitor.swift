import Foundation
import Network

protocol Connectivity: Sendable {
    func isOnline() -> Bool
}

struct OnlineConnectivity: Connectivity {
    func isOnline() -> Bool { true }
}

struct OfflineConnectivity: Connectivity {
    func isOnline() -> Bool { false }
}

final class NetworkMonitor: Connectivity, @unchecked Sendable {
    private let monitor = NWPathMonitor()

    init() {
        monitor.start(queue: DispatchQueue(label: "com.meetrecap.network"))
    }

    func isOnline() -> Bool {
        monitor.currentPath.status == .satisfied
    }

    deinit {
        monitor.cancel()
    }
}
