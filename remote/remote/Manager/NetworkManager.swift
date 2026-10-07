import Foundation
import Network
import UIKit

final class NetworkManager {

    static let shared = NetworkManager()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.app.networkmanager.monitor", qos: .utility)

    private(set) var isConnected = true

    var onConnectivityChange: ((Bool) -> Void)?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            ThreadManager.onMain {
                guard let self else { return }
                let didChange = self.isConnected != connected
                self.isConnected = connected
                LoggerManager.network(
                    "Connectivity updated — online: \(connected), interface: \(path.availableInterfaces.map(\.type).description)",
                    category: "Network"
                )
                if didChange {
                    NetworkAnalyticsManager.trackConnectivityChange(
                        isConnected: connected,
                        connectionType: NetworkMonitor.connectionTypeLabel(from: path)
                    )
                    self.onConnectivityChange?(connected)
                }
            }
        }
        monitor.start(queue: queue)
        LoggerManager.info("NetworkManager started monitoring", category: "Network")
    }

    func checkConnectivity() -> Bool {
        isConnected
    }

    @discardableResult
    func requireConnectivity(
        from viewController: UIViewController,
        title: String = Strings.shared.alert_title_error,
        message: String = Strings.shared.no_internet_message
    ) -> Bool {
        guard isConnected else {
            LoggerManager.warning("Network required but device is offline", category: "Network")
            AlertHelper.presentOKAlert(from: viewController, title: title, message: message)
            return false
        }
        return true
    }
}
