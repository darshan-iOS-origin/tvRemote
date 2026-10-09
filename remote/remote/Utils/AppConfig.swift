import Foundation

/// Fixed facts about the app on the App Store. Change them here.
enum AppConfig {

    /// The app's App Store id.
    static let appStoreID = "6819992214"

    /// The app's page on the App Store, for sharing.
    static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    /// The RevenueCat public Apple SDK key: RevenueCat dashboard > Project settings > API keys > your iOS app.
    /// It starts with "appl_" and is meant to ship inside the app. Do not use a Test Store key in a build for
    /// the App Store. Paste it here; while the text still says PASTE, purchases stay off and the log says so.
    static let revenueCatAPIKey = "appl_ZLMuUcMIyYyXuKULDChoaMhxwMq"

    /// Linked from the subscription screens (Apple requires both). TODO: replace with the real pages.
    static let privacyPolicyURL = URL(string: "https://example.com/privacy")

    /// TODO: replace with the real page.
    static let termsOfServiceURL = URL(string: "https://example.com/terms")

    /// Opens the App Store's "Write a Review" screen for the app.
    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
