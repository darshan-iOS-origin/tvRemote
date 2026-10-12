import FacebookCore
import Foundation

/// The one place that sends events to Facebook App Events.
///
/// Only screen events go to Facebook, with exactly the same names as Firebase (`FirebaseEvents.Screen`).
/// Taps, results, permission, IAP, trial and renewal events never reach Facebook: this class has no method
/// for them. Events carry no parameters. Called from `AnalyticsManager.logScreen`.
final class FacebookEvents {

    static let shared = FacebookEvents()

    private static let category = "Facebook"

    /// Facebook allows 40 characters; this app's Firebase names are at most 35, so the same name always fits.
    private static let maxNameLength = 40

    private init() {}

    /// Logs one screen event, e.g. `FirebaseEvents.Screen.remote`. Does nothing until the Facebook SDK is
    /// started (`FacebookManager.configure`). Returns whether the event was handed to the SDK.
    @discardableResult
    func logScreen(_ name: String) -> Bool {
        guard Self.isValid(name) else {
            LoggerManager.error(
                "Facebook event \(name) dropped: name must be 1-\(Self.maxNameLength) letters, digits, underscores, hyphens or spaces",
                category: Self.category
            )
            return false
        }
        guard FacebookManager.shared.isConfigured else {
            LoggerManager.error("Facebook event \(name) dropped: Facebook SDK is not configured", category: Self.category)
            return false
        }
        AppEvents.shared.logEvent(AppEvents.Name(name))
        #if DEBUG
        // Send now instead of waiting for the SDK's batch timer, so the SDK log shows the request and the reply.
        AppEvents.shared.flush()
        #endif
        LoggerManager.success("Facebook event logged: \(name)", category: Self.category)
        return true
    }

    private static func isValid(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= maxNameLength else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- ")
        return name.unicodeScalars.allSatisfy(allowed.contains)
    }
}
