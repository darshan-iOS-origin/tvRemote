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
        #if DEBUG
        // Prints the SDK's own Analytics lines in the Xcode console: "Logging event: origin, name, params"
        // for every event, and the upload status. Debug builds only.
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        #endif
        FirebaseApp.configure(options: options)
        if FirebaseApp.app() != nil {
            LoggerManager.success("Firebase configured", category: category)
        } else {
            LoggerManager.error("Firebase configuration failed", category: category)
        }
    }
}
