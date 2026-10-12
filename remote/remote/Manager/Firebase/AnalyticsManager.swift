import FirebaseAnalytics
import FirebaseCore

final class AnalyticsManager {

    static let shared = AnalyticsManager()

    private static let category = "Analytics"

    private init() {}

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

    func logAppColdStart() {
        log(FirebaseEvents.appColdStart)
    }
}
