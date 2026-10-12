import UIKit

/// The one place that decides when to show the system "Rate this app" alert.
///
/// It is asked after a feature succeeded (`requestAfterSuccess`) and shows the alert at most ONCE per install:
/// the "already asked" flag is saved before the alert is requested, a second call while one is waiting is
/// ignored, and no call is acted on during an IAP session. iOS itself also limits how often the alert can appear.
///
/// Features that ask: Connect, Voice, Cast (when it ends), Screen Mirror on the TV (when it ends), App Icon,
/// App Theme.
@MainActor
enum RateUsManager {

    enum Trigger: String {
        case connect, voice, cast, mirror, appIcon, appTheme
    }

    private static let askedKey = "RateUsManager.asked"
    private static var isWaiting = false

    /// True once the alert was requested on this install.
    static var hasAsked: Bool {
        UserDefaults.standard.bool(forKey: askedKey)
    }

    /// Call right after `trigger`'s feature succeeded. `delay` lets the screen settle (or a system alert go away)
    /// before the rate alert is requested.
    static func requestAfterSuccess(_ trigger: Trigger, delay: TimeInterval = 1.5) {
        guard !hasAsked, !isWaiting else { return }
        isWaiting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isWaiting = false
            // Not while the user is in the IAP screens, and only while the app is on screen.
            guard !hasAsked, IAPTracker.currentEntry == nil, UIApplication.shared.applicationState == .active else {
                LoggerManager.info("Rate alert skipped after \(trigger.rawValue)", category: "RateUs")
                return
            }
            UserDefaults.standard.set(true, forKey: askedKey)
            LoggerManager.info("Rate alert requested after \(trigger.rawValue)", category: "RateUs")
            requestDefaultAppStoreReview()
        }
    }
}
