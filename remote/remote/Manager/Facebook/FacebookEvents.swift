import FacebookCore
import Foundation

/// The one place that sends events to Facebook App Events.
///
/// Only screen events go to Facebook, with exactly the same names as Firebase (`FirebaseEvents.Screen`).
/// Taps, results, permission, IAP, trial and renewal events never reach Facebook: this class has no method
/// for them. Events carry no parameters. Called from `AnalyticsManager.logScreen`.
final class FacebookEvents {

    static let shared = FacebookEvents()

    /// Facebook allows 40 characters; this app's Firebase names are at most 35, so the same name always fits.
    private static let maxNameLength = 40

    private init() {}

    /// Logs one screen event, e.g. `FirebaseEvents.Screen.remote`. Does nothing until the Facebook SDK is
    /// started (`FacebookManager.configure`). Returns whether the event was handed to the SDK.
    @discardableResult
    func logScreen(_ name: String) -> Bool {
        send(name)
    }

    /// Facebook-only entry point of an IAP screen, e.g. `iap_open_setting_banner_main`. Sent when the IAP screen
    /// appears (`IAPTracker.screenAppeared`), not when the button is tapped. Firebase never gets this name.
    @discardableResult
    func logIAPEntry(_ name: String) -> Bool {
        send(name)
    }

    private func send(_ name: String) -> Bool {
        guard Self.isValid(name) else {
            EventLog.dropped(.facebook, name, reason: "name must be 1-\(Self.maxNameLength) letters, digits, underscores, hyphens or spaces")
            return false
        }
        guard FacebookManager.shared.isConfigured else {
            EventLog.dropped(.facebook, name, reason: "Facebook SDK is not configured")
            return false
        }
        AppEvents.shared.logEvent(AppEvents.Name(name))
        #if DEBUG
        // Send now instead of waiting for the SDK's batch timer, so the SDK log shows the request and the reply.
        AppEvents.shared.flush()
        #endif
        EventLog.sent(.facebook, name)
        return true
    }

    private static func isValid(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= maxNameLength else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- ")
        return name.unicodeScalars.allSatisfy(allowed.contains)
    }
}
