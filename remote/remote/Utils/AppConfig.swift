import Foundation

/// Fixed facts about the app on the App Store. Change them here.
enum AppConfig {

    /// The app's App Store id.
    static let appStoreID = "6819992214"

    /// The app's page on the App Store, for sharing.
    static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    /// Opens the App Store's "Write a Review" screen for the app.
    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
