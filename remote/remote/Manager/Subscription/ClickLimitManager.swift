import UIKit

/// The free taps on the screens that are limited for users without Premium. Each `Kind` has its own
/// Firebase Remote Config limit, stored limit and used count (all in `AppSettings`); the tap after the
/// limit opens the Subscription screen instead of doing the action.
final class ClickLimitManager {

    static let shared = ClickLimitManager()

    /// Used when no value has been fetched or stored yet.
    static let defaultLimit = 5

    enum Kind {
        /// Key taps on the Remote and Keyboard tabs (`remote_click_limit`).
        case remote
        /// Starting screen mirroring (`screen_mirror_click_limit`).
        case screenMirror
        /// Adding a TV (`add_new_tv_limit`). Not a tap counter: the used amount is the number of saved TVs.
        case addTV

        fileprivate var storedLimit: Int? {
            get {
                switch self {
                case .addTV: return AppSettings.addNewTVLimit
                case .remote: return AppSettings.remoteClickLimit
                case .screenMirror: return AppSettings.screenMirrorClickLimit
                }
            }
            nonmutating set {
                switch self {
                case .addTV: AppSettings.addNewTVLimit = newValue
                case .remote: AppSettings.remoteClickLimit = newValue
                case .screenMirror: AppSettings.screenMirrorClickLimit = newValue
                }
            }
        }

        fileprivate var count: Int {
            get {
                switch self {
                case .addTV: return UserDefaultsDeviceStore().load().count
                case .remote: return AppSettings.remoteClickCount
                case .screenMirror: return AppSettings.screenMirrorClickCount
                }
            }
            nonmutating set {
                switch self {
                case .addTV: break
                case .remote: AppSettings.remoteClickCount = newValue
                case .screenMirror: AppSettings.screenMirrorClickCount = newValue
                }
            }
        }

        fileprivate var fetchedLimit: Int {
            switch self {
            case .addTV: return RemoteConfigManager.shared.addNewTVLimit
            case .remote: return RemoteConfigManager.shared.remoteClickLimit
            case .screenMirror: return RemoteConfigManager.shared.screenMirrorClickLimit
            }
        }
    }

    private init() {}

    /// The limit in force: the stored copy, or the default before anything has been stored.
    func limit(for kind: Kind) -> Int {
        kind.storedLimit ?? Self.defaultLimit
    }

    /// Stores the fetched limit when it differs from the stored one. The used count is kept.
    func syncLimit(with fetched: Int, for kind: Kind) {
        guard kind.storedLimit != fetched else { return }
        LoggerManager.debug("Click limit \(kind) \(kind.storedLimit.map(String.init) ?? "none") -> \(fetched)", category: "RemoteConfig")
        kind.storedLimit = fetched
    }

    /// Syncs every limit with the current Remote Config values.
    func syncAllLimits() {
        for kind in [Kind.remote, .screenMirror, .addTV] {
            syncLimit(with: kind.fetchedLimit, for: kind)
        }
    }

    /// Call before connecting to a TV. A TV that is already saved is always allowed. A new one is allowed
    /// while fewer than `add_new_tv_limit` TVs are saved; otherwise the Subscription screen opens and the
    /// connection must not start. Premium users are never limited.
    @MainActor
    func allowNewTV(_ device: TVDevice, from presenter: UIViewController) -> Bool {
        if SubscriptionManager.shared.isPremium { return true }
        let store = UserDefaultsDeviceStore()
        if store.contains(device) || store.load().count < limit(for: .addTV) { return true }
        // Show it over whatever is on top (the scan screen is usually presented over the app).
        var top = presenter
        while let presented = top.presentedViewController { top = presented }
        if !(top is SubscriptionVC) {
            NavigationManager.shared.showSubscription(from: top)
        }
        return false
    }

    /// Call when the action is about to happen. True: go ahead (a free tap was used, or the user is Premium).
    /// False: the free taps are used up; the Subscription screen is opening and the action must not happen.
    @MainActor
    func allowTap(for kind: Kind = .remote, from presenter: UIViewController) -> Bool {
        if SubscriptionManager.shared.isPremium { return true }
        if kind.count < limit(for: kind) {
            kind.count += 1
            return true
        }
        // A fast second tap must not stack another Subscription screen.
        if presenter.presentedViewController == nil && presenter.tabBarController?.presentedViewController == nil {
            NavigationManager.shared.showSubscription(from: presenter)
        }
        return false
    }
}
