import FirebaseAnalytics
import FirebaseCore

/// The one place that sends custom events to Firebase Analytics.
///
/// Event names and parameter keys come from `FirebaseEvents`.
final class AnalyticsManager {

    static let shared = AnalyticsManager()

    private static let category = "Analytics"

    private init() {}

    /// Logs one event. Does nothing when Firebase is not configured.
    func log(_ name: String, parameters: [String: Any]? = nil) {
        guard FirebaseApp.app() != nil else {
            LoggerManager.error(
                "Analytics event \(name) dropped: Firebase is not configured",
                category: Self.category
            )
            return
        }
        Analytics.logEvent(name, parameters: parameters)
        let details = parameters.map { " \($0)" } ?? ""
        LoggerManager.success("Event logged: \(name)\(details)", category: Self.category)
    }

    /// Logs `app_cold_start`. Call once per process, from `AppDelegate` after Firebase is configured.
    func logAppColdStart() {
        LoggerManager.info("App cold start", category: Self.category)
        log(FirebaseEvents.appColdStart)
    }
}
