import UIKit

/// The free key taps on the Remote and Keyboard tabs. `remote_click_limit` (Firebase Remote Config) says
/// how many a user without Premium gets; the tap after that opens the Subscription screen instead of
/// sending the key. The limit and the used count are kept in `AppSettings`.
final class ClickLimitManager {

    static let shared = ClickLimitManager()

    /// Used when no value has been fetched or stored yet.
    static let defaultLimit = 5

    private init() {}

    /// The limit in force: the stored copy, or the default before anything has been stored.
    var limit: Int {
        AppSettings.remoteClickLimit ?? Self.defaultLimit
    }

    /// Stores the fetched limit when it differs from the stored one. The used count is kept.
    func syncLimit(with fetched: Int) {
        guard AppSettings.remoteClickLimit != fetched else { return }
        LoggerManager.debug("Click limit \(AppSettings.remoteClickLimit.map(String.init) ?? "none") -> \(fetched)", category: "RemoteConfig")
        AppSettings.remoteClickLimit = fetched
    }

    /// Call when a key is about to be sent. True: send it (a free tap was used, or the user is Premium).
    /// False: the free taps are used up; the Subscription screen is opening and the key must not be sent.
    @MainActor
    func allowTap(from presenter: UIViewController) -> Bool {
        if SubscriptionManager.shared.isPremium { return true }
        if AppSettings.remoteClickCount < limit {
            AppSettings.remoteClickCount += 1
            return true
        }
        // A fast second tap must not stack another Subscription screen.
        if presenter.presentedViewController == nil && presenter.tabBarController?.presentedViewController == nil {
            NavigationManager.shared.showSubscription(from: presenter)
        }
        return false
    }
}
