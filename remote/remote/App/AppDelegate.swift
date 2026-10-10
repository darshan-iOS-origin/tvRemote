import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseManager.configure()
        RemoteConfigManager.shared.setUp()
        Task { await RemoteConfigManager.shared.fetchAndActivate() }
        KeyboardManager.startObserving()
        _ = NetworkManager.shared
        SubscriptionManager.shared.configure()
        Task { await SubscriptionManager.shared.loadProducts() }
        return true
    }

}
