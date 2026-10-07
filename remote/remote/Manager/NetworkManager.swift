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
        title: String = "Error",
        message: String = "No internet connection. Please check your network and try again."
    ) -> Bool {
        guard isConnected else {
            LoggerManager.warning("Network required but device is offline", category: "Network")
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)
            return false
        }
        return true
    }
}
