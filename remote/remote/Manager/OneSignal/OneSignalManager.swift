import OneSignalFramework
import UIKit

/// The one place that talks to OneSignal.
///
/// Call `configure(launchOptions:)` once from `AppDelegate`. An empty `AppConfig.oneSignalAppID`
/// leaves push off; the rest of the app keeps working. Permission is requested later, from
/// `LaunchPermissionManager`, so the first-launch prompt stays in one place.
final class OneSignalManager {

    static let shared = OneSignalManager()

    /// True after a non-empty App ID has been passed to `OneSignal.initialize`.
    private(set) var isConfigured = false

    private init() {}

    /// Starts OneSignal. Safe to call more than once. Does nothing when the App ID is still empty.
    func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !isConfigured else { return }
        let appID = AppConfig.oneSignalAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty else {
            LoggerManager.error(
                "OneSignal App ID is missing. Paste it into AppConfig.oneSignalAppID. Push stays off until then.",
                category: "OneSignal"
            )
            return
        }
        #if DEBUG
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        let level = "verbose"
        #else
        OneSignal.Debug.setLogLevel(.LL_WARN)
        let level = "warn"
        #endif
        OneSignal.initialize(appID, withLaunchOptions: launchOptions)
        isConfigured = true
        LoggerManager.success("OneSignal configured (log level \(level))", category: "OneSignal")
    }

    /// Asks for alert, badge, and sound, and registers the device with OneSignal.
    /// Call only when `isConfigured` is true.
    func requestPermission() async -> Bool {
        guard isConfigured else { return false }
        return await withCheckedContinuation { continuation in
            OneSignal.Notifications.requestPermission({ accepted in
                continuation.resume(returning: accepted)
            }, fallbackToSettings: false)
        }
    }
}
