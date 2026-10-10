import FirebaseCore

/// Starts Firebase. Call `configure()` once, first thing at launch.
enum FirebaseManager {

    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}
