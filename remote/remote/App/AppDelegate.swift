import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        KeyboardManager.startObserving()
        _ = NetworkManager.shared
        // RevenueCat first, so `isPremium` is right before any screen reads it. Then the store prices load
        // in the background, ready for the paywalls.
        SubscriptionManager.shared.configure()
        Task { await SubscriptionManager.shared.loadProducts() }
        return true
    }

}
