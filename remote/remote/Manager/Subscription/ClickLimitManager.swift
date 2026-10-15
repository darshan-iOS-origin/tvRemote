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
        /// Screen mirroring (`screen_mirror_click_limit`, in minutes; the used amount is seconds mirrored).
        case screenMirror
        /// Adding a TV (`add_new_tv_limit`). Not a tap counter: the used amount is the number of saved TVs.
        case addTV
        /// Casting photos and videos to the TV (`screen_cast_limit`). The used count is the number of items cast.
        case cast

        fileprivate var storedLimit: Int? {
            get {
                switch self {
                case .addTV: return AppSettings.addNewTVLimit
                case .remote: return AppSettings.remoteClickLimit
                case .screenMirror: return AppSettings.screenMirrorClickLimit
                case .cast: return AppSettings.screenCastLimit
                }
            }
            nonmutating set {
                switch self {
                case .addTV: AppSettings.addNewTVLimit = newValue
                case .remote: AppSettings.remoteClickLimit = newValue
                case .screenMirror: AppSettings.screenMirrorClickLimit = newValue
                case .cast: AppSettings.screenCastLimit = newValue
                }
            }
        }

        /// 0 normal limit, 1 second-time limit, 2 restricted (only screen mirroring and casting move).
        fileprivate var stage: Int {
            get {
                switch self {
                case .screenMirror: return AppSettings.limitStage("mirror")
                case .cast: return AppSettings.limitStage("cast")
                default: return 0
                }
            }
            nonmutating set {
                switch self {
                case .screenMirror: AppSettings.setLimitStage(newValue, "mirror")
                case .cast: AppSettings.setLimitStage(newValue, "cast")
                default: break
                }
            }
        }

        /// Only screen mirroring and casting have a separate limit for the second launch.
        fileprivate var secondStoredLimit: Int? {
            get {
                switch self {
                case .screenMirror: return AppSettings.screenMirrorSecondLimit
                case .cast: return AppSettings.screenCastSecondLimit
                default: return nil
                }
            }
            nonmutating set {
                switch self {
                case .screenMirror: AppSettings.screenMirrorSecondLimit = newValue
                case .cast: AppSettings.screenCastSecondLimit = newValue
                default: break
                }
            }
        }

        fileprivate var secondFetchedLimit: Int? {
            switch self {
            case .screenMirror: return RemoteConfigManager.shared.screenMirrorClickLimitSecondTime
            case .cast: return RemoteConfigManager.shared.screenCastLimitSecondTime
            default: return nil
            }
        }

        /// The used amount in force: the second-launch counter during the second launch, the normal one otherwise.
        fileprivate var count: Int {
            get {
                switch self {
                case .addTV: return UserDefaultsDeviceStore().load().count
                case .remote: return AppSettings.remoteClickCount
                case .screenMirror:
                    return (self.stage == 1) ? AppSettings.screenMirrorSecondCount : AppSettings.screenMirrorClickCount
                case .cast:
                    return (self.stage == 1) ? AppSettings.screenCastSecondCount : AppSettings.screenCastCount
                }
            }
            nonmutating set {
                switch self {
                case .addTV: break
                case .remote: AppSettings.remoteClickCount = newValue
                case .screenMirror:
                    if (self.stage == 1) { AppSettings.screenMirrorSecondCount = newValue }
                    else { AppSettings.screenMirrorClickCount = newValue }
                case .cast:
                    if (self.stage == 1) { AppSettings.screenCastSecondCount = newValue }
                    else { AppSettings.screenCastCount = newValue }
                }
            }
        }

        fileprivate var fetchedLimit: Int {
            switch self {
            case .addTV: return RemoteConfigManager.shared.addNewTVLimit
            case .remote: return RemoteConfigManager.shared.remoteClickLimit
            case .screenMirror: return RemoteConfigManager.shared.screenMirrorClickLimit
            case .cast: return RemoteConfigManager.shared.screenCastLimit
            }
        }
    }

    private init() {}

    /// Call once per launch. For screen mirroring and casting, moves from the normal limit to the second-time
    /// limit, and from that to restricted, but only if the current limit was used at all. Unused: it stays.
    func advanceStagesOnLaunch() {
        for kind in [Kind.screenMirror, .cast] {
            let stage = kind.stage
            if stage == 0, kind.count > 0 { kind.stage = 1 }
            else if stage == 1, kind.count > 0 { kind.stage = 2 }
        }
    }

    /// The limit in force. Screen mirroring and casting: the normal limit until it has been used and the app
    /// relaunched, then only the `_second_time` limit, and after that none. Otherwise the stored copy, or the
    /// default before anything has been stored.
    func limit(for kind: Kind) -> Int {
        if kind == .screenMirror || kind == .cast {
            if kind.stage >= 2 { return 0 }
            if kind.stage == 1 { return kind.secondStoredLimit ?? Self.defaultLimit }
        }
        return kind.storedLimit ?? Self.defaultLimit
    }

    /// Stores the fetched limit when it differs from the stored one. The used count is kept.
    func syncLimit(with fetched: Int, for kind: Kind) {
        guard kind.storedLimit != fetched else { return }
        LoggerManager.debug("Click limit \(kind) \(kind.storedLimit.map(String.init) ?? "none") -> \(fetched)", category: "RemoteConfig")
        kind.storedLimit = fetched
    }

    /// Syncs every limit with the current Remote Config values.
    func syncAllLimits() {
        for kind in [Kind.remote, .screenMirror, .addTV, .cast] {
            syncLimit(with: kind.fetchedLimit, for: kind)
            if let second = kind.secondFetchedLimit, kind.secondStoredLimit != second {
                kind.secondStoredLimit = second
            }
        }
    }

    /// Call before connecting to a TV. A TV that is already saved is always allowed. A new one is allowed
    /// while fewer than `add_new_tv_limit` TVs are saved; otherwise the Subscription screen opens and the
    /// connection must not start. Premium users are never limited.
    @MainActor
    func allowNewTV(_ device: TVDevice, event: String, from presenter: UIViewController) -> Bool {
        if SubscriptionManager.shared.isPremium { return true }
        let store = UserDefaultsDeviceStore()
        if store.contains(device) || store.load().count < limit(for: .addTV) { return true }
        // Show it over whatever is on top (the scan screen is usually presented over the app).
        var top = presenter
        while let presented = top.presentedViewController { top = presented }
        if !(top is SubscriptionVC) {
            NavigationManager.shared.showSubscription(from: top, event: event)
        }
        return false
    }

    /// Call when the action is about to happen. True: go ahead (a free tap was used, or the user is Premium).
    /// False: the free taps are used up; the Subscription screen is opening and the action must not happen.
    @MainActor
    func allowTap(for kind: Kind = .remote, event: String, from presenter: UIViewController) -> Bool {
        if SubscriptionManager.shared.isPremium { return true }
        if kind.count < limit(for: kind) {
            kind.count += 1
            return true
        }
        // A fast second tap must not stack another Subscription screen.
        if presenter.presentedViewController == nil && presenter.tabBarController?.presentedViewController == nil {
            NavigationManager.shared.showSubscription(from: presenter, event: event)
        }
        return false
    }

    // MARK: - Screen mirroring time

    /// Screen mirroring is limited by time: the limit is in minutes, the used amount in seconds.
    /// Seconds of free mirroring left (`Int.max` for Premium).
    var mirrorSecondsLeft: Int {
        if SubscriptionManager.shared.isPremium { return .max }
        return max(0, limit(for: .screenMirror) * 60 - Kind.screenMirror.count)
    }

    /// Adds mirrored seconds to the used time. Not for Premium.
    func addMirrorSeconds(_ seconds: Int) {
        guard seconds > 0, !SubscriptionManager.shared.isPremium else { return }
        Kind.screenMirror.count += seconds
    }

    /// Call when mirroring is about to start. False: no free time is left and the Subscription screen is opening.
    @MainActor
    func allowMirrorStart(event: String, from presenter: UIViewController) -> Bool {
        if mirrorSecondsLeft > 0 { return true }
        var top = presenter
        while let presented = top.presentedViewController { top = presented }
        if !(top is SubscriptionVC) {
            NavigationManager.shared.showSubscription(from: top, event: event)
        }
        return false
    }

    /// Opens the Subscription screen over whatever is on top, when the free mirroring time ran out while
    /// mirroring (no screen of ours started it).
    @MainActor
    func showSubscriptionForMirrorLimit(event: String) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController ?? scene?.windows.first?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        if !(top is SubscriptionVC) {
            NavigationManager.shared.showSubscription(from: top, event: event)
        }
    }

    /// Free photos and videos used and the free total, for the message on the picker. nil for Premium.
    var castUsage: (used: Int, limit: Int)? {
        if SubscriptionManager.shared.isPremium { return nil }
        let total = limit(for: .cast)
        return (min(Kind.cast.count, total), total)
    }

    /// Free photos and videos still left to cast. nil for Premium (no limit).
    var castRemaining: Int? {
        castUsage.map { max(0, $0.limit - $0.used) }
    }

    /// True when a user without Premium has no free casts left (always false for Premium).
    var isCastLimitReached: Bool {
        if SubscriptionManager.shared.isPremium { return false }
        return Kind.cast.count >= limit(for: .cast)
    }

    /// Call when `count` photos or videos are about to be cast. True: go ahead (they fit in the free limit, so
    /// they are counted, or the user is Premium). False: they would go past the limit; the Subscription screen
    /// is opening and nothing may be cast.
    @MainActor
    func allowCast(count: Int, event: String, from presenter: UIViewController) -> Bool {
        if SubscriptionManager.shared.isPremium { return true }
        if Kind.cast.count + count <= limit(for: .cast) {
            Kind.cast.count += count
            return true
        }
        var top = presenter
        while let presented = top.presentedViewController { top = presented }
        if !(top is SubscriptionVC) {
            NavigationManager.shared.showSubscription(from: top, event: event)
        }
        return false
    }
}
