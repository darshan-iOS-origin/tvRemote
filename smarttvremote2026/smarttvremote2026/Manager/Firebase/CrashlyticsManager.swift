import FirebaseCore
import FirebaseCrashlytics

/// The one place that talks to Firebase Crashlytics.
///
/// Call `configure()` once from `AppDelegate`, after `FirebaseManager.configure()`.
final class CrashlyticsManager {

    static let shared = CrashlyticsManager()

    private static let category = "Crashlytics"

    /// True after collection has been turned on.
    private(set) var isConfigured = false

    private init() {}

    /// Starts Crashlytics. Safe to call more than once. Does nothing when Firebase is not configured.
    func configure() {
        guard !isConfigured else { return }
        guard FirebaseApp.app() != nil else {
            LoggerManager.error(
                "Crashlytics did not start: Firebase is not configured",
                category: Self.category
            )
            return
        }
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        isConfigured = true
        LoggerManager.success("Crashlytics configured", category: Self.category)
    }

    /// Adds a log line that appears on the next crash or non-fatal report.
    func log(_ message: String) {
        guard isConfigured else { return }
        Crashlytics.crashlytics().log(message)
    }

    /// Attaches a key-value pair to the next crash or non-fatal report.
    func setCustomValue(_ value: Any, forKey key: String) {
        guard isConfigured else { return }
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Records a non-fatal error.
    func record(error: Error) {
        guard isConfigured else { return }
        Crashlytics.crashlytics().record(error: error)
    }

    #if DEBUG
    /// Forces a crash so the first report can be checked in the Firebase console.
    /// Run the app without the debugger attached, then launch it again.
    func forceTestCrash() {
        fatalError("Crashlytics test crash")
    }
    #endif
}
