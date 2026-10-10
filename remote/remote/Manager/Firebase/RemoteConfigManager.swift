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
        config.setDefaults(Dictionary(uniqueKeysWithValues: Key.allCases.map { ($0.rawValue, NSNumber(value: true)) }))
        remoteConfig = config
    }

    // MARK: - Values

    var isMainScreenEnabled: Bool { bool(.iapMainScreen) }
    var isYearOfferScreenEnabled: Bool { bool(.iapYearOfferScreen) }
    var isFreeTrialScreenEnabled: Bool { bool(.iapFreeTrialScreen) }

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
                once.finish(error == nil && status != .error)
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
