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

        fileprivate var storedLimit: Int? {
            get {
                switch self {
                case .remote: return AppSettings.remoteClickLimit
                case .screenMirror: return AppSettings.screenMirrorClickLimit
                }
            }
            nonmutating set {
                switch self {
                case .remote: AppSettings.remoteClickLimit = newValue
                case .screenMirror: AppSettings.screenMirrorClickLimit = newValue
                }
            }
        }

        fileprivate var count: Int {
            get {
                switch self {
                case .remote: return AppSettings.remoteClickCount
                case .screenMirror: return AppSettings.screenMirrorClickCount
                }
            }
            nonmutating set {
                switch self {
                case .remote: AppSettings.remoteClickCount = newValue
                case .screenMirror: AppSettings.screenMirrorClickCount = newValue
                }
            }
        }

        fileprivate var fetchedLimit: Int {
            switch self {
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
        for kind in [Kind.remote, .screenMirror] {
            syncLimit(with: kind.fetchedLimit, for: kind)
        }
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
