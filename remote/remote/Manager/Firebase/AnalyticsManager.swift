import FirebaseAnalytics
import FirebaseCore

final class AnalyticsManager {

    static let shared = AnalyticsManager()

    private static let category = "⎯ Analytics"

    private init() {}

    /// Added to the name of tap and feature success/fail events when the user is Premium, e.g.
    /// `pro_remote_play_tap`. Free users send the plain name.
    static let premiumPrefix = "pro_"

    /// Returns whether the event was sent. `marksPremium` is true for taps and feature success/fail events
    /// (the default); screens, permissions, IAP and trial events pass false and keep the same name for everyone.
    @discardableResult
    func log(_ rawName: String, parameters: [String: Any]? = nil, marksPremium: Bool = true) -> Bool {
        let name = marksPremium && AppSettings.isPremium ? Self.premiumPrefix + rawName : rawName
        guard Self.isValid(name) else {
            LoggerManager.error(
                "Analytics event \(name) dropped: name must be 1-\(FirebaseEvents.maxNameLength) letters, digits or underscores and start with a letter",
                category: Self.category
            )
            return false
        }
        guard FirebaseApp.app() != nil else {
            LoggerManager.error(
                "Analytics event \(name) dropped: Firebase is not configured",
                category: Self.category
            )
            return false
        }
        Analytics.logEvent(name, parameters: parameters)
        let details = parameters.map { " \($0)" } ?? ""
        LoggerManager.success("Event logged: \(name)\(details)", category: Self.category)
        return true
    }

    /// Logs the event only the first time ever on this install (kept in `UserDefaults`).
    func logOnce(_ name: String) {
        let key = "analytics.once.\(name)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        if log(name, marksPremium: false) {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    func logAppColdStart() {
        log(FirebaseEvents.appColdStart, marksPremium: false)
    }

    /// Logs one screen event, e.g. `FirebaseEvents.Screen.remote`.
    func logScreen(_ eventName: String) {
        log(eventName, marksPremium: false)
    }

    private static func isValid(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first,
              name.count <= FirebaseEvents.maxNameLength,
              !name.hasPrefix("firebase_"), !name.hasPrefix("google_"), !name.hasPrefix("ga_")
        else { return false }
        let letters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let allowed = letters.union(CharacterSet(charactersIn: "0123456789_"))
        return letters.contains(first) && name.unicodeScalars.allSatisfy(allowed.contains)
    }
}
