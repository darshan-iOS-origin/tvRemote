import Foundation

/// Fixed facts about the app on the App Store. Change them here.
enum AppConfig {

    static let appStoreID = "6819992214"

    static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    static let revenueCatAPIKey = "appl_ZLMuUcMIyYyXuKULDChoaMhxwMq"

    static let privacyPolicyURL = URL(string: "https://example.com/privacy")

    static let termsOfServiceURL = URL(string: "https://example.com/terms")

    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
