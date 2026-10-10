import FirebaseCore
import Foundation
import FirebaseRemoteConfig

/// The Firebase Remote Config values the app reads. Every key has a default, so the app behaves the
/// same offline or before the first fetch finishes.
final class RemoteConfigManager {

    static let shared = RemoteConfigManager()

    /// The Remote Config keys, exactly as named in the Firebase console.
    enum Key: String, CaseIterable {
        case iapMainScreen = "iap_main_screen"
        case iapYearOfferScreen = "iap_year_offer_screen"
        case iapFreeTrialScreen = "iap_free_trial_screen"
        /// Number: how many key taps a non-premium user gets for free on the Remote and Keyboard tabs.
        case remoteClickLimit = "remote_click_limit"
        /// Number: how many times a non-premium user may start screen mirroring for free.
        case screenMirrorClickLimit = "screen_mirror_click_limit"
        /// Number: how many different TVs a non-premium user may add (connect to and save).
        case addNewTVLimit = "add_new_tv_limit"
        /// Boolean: show the free trial (text in the Yearly plan card, "3 Day Free Trial" button) or hide it.
        case yearFreeTrial = "year_free_trial"
        /// Boolean: the same for the Monthly plan.
        case monthFreeTrial = "month_free_trial"

        /// Used until the first fetch has been activated (and when the console has no value).
        var defaultValue: NSNumber {
            switch self {
            case .remoteClickLimit, .screenMirrorClickLimit, .addNewTVLimit: return NSNumber(value: ClickLimitManager.defaultLimit)
            default: return NSNumber(value: true)
            }
        }
    }

    private init() {}

    private var remoteConfig: RemoteConfig?
    private var didSetUp = false

    /// Call after `FirebaseManager.configure()`. Safe to call more than once.
    func setUp() {
        guard !didSetUp, FirebaseApp.app() != nil else { return }
        didSetUp = true
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        config.configSettings = settings
        config.setDefaults(Dictionary(uniqueKeysWithValues: Key.allCases.map { ($0.rawValue, $0.defaultValue) }))
        remoteConfig = config
        ClickLimitManager.shared.syncAllLimits()
    }

    // MARK: - Values

    var isMainScreenEnabled: Bool { bool(.iapMainScreen) }
    var isYearOfferScreenEnabled: Bool { bool(.iapYearOfferScreen) }
    var isFreeTrialScreenEnabled: Bool { bool(.iapFreeTrialScreen) }
    var isYearFreeTrialEnabled: Bool { bool(.yearFreeTrial) }
    var isMonthFreeTrialEnabled: Bool { bool(.monthFreeTrial) }

    /// Free key taps before the Subscription screen opens. Never negative.
    var remoteClickLimit: Int { number(.remoteClickLimit) }

    /// Free screen mirroring starts before the Subscription screen opens. Never negative.
    var screenMirrorClickLimit: Int { number(.screenMirrorClickLimit) }

    /// How many TVs a user without Premium may add. Never negative.
    var addNewTVLimit: Int { number(.addNewTVLimit) }

    private func number(_ key: Key) -> Int {
        guard let remoteConfig else { return ClickLimitManager.defaultLimit }
        return max(0, remoteConfig.configValue(forKey: key.rawValue).numberValue.intValue)
    }

    private func bool(_ key: Key) -> Bool {
        remoteConfig?.configValue(forKey: key.rawValue).boolValue ?? true
    }

    // MARK: - Fetch

    /// Fetches and activates the latest values. Never throws and never waits longer than `timeout`
    /// seconds: on a failure or a timeout the last activated values (or the defaults) stay in use.
    @discardableResult
    func fetchAndActivate(timeout: TimeInterval = 3) async -> Bool {
        setUp()
        guard let remoteConfig else { return false }
        return await withCheckedContinuation { continuation in
            let once = Once(continuation)
            remoteConfig.fetchAndActivate { status, error in
                if let error {
                    LoggerManager.debug("Remote Config fetch failed: \(error.localizedDescription)", category: "RemoteConfig")
                }
                let succeeded = error == nil && status != .error
                if succeeded {
                    // The fetched number replaces the stored one when they differ.
                    DispatchQueue.main.async { ClickLimitManager.shared.syncAllLimits() }
                }
                once.finish(succeeded)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                once.finish(false)
            }
        }
    }
}

/// Resumes a continuation exactly once, whichever of the fetch or the timeout comes first.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func finish(_ value: Bool) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
