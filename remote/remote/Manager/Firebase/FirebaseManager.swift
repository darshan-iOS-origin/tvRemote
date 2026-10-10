import FirebaseCore

/// Starts Firebase. Call `configure()` once, first thing at launch.
enum FirebaseManager {

    private static let category = "Firebase"

    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        guard let options = FirebaseOptions.defaultOptions() else {
            LoggerManager.error(
                "Firebase configuration failed: GoogleService-Info.plist was not found",
                category: category
            )
            return
        }
        FirebaseApp.configure(options: options)
        if FirebaseApp.app() != nil {
            LoggerManager.success("Firebase configured", category: category)
        } else {
            LoggerManager.error("Firebase configuration failed", category: category)
        }
    }
}
