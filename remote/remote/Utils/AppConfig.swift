import Foundation

/// Fixed facts about the app on the App Store. Change them here.
enum AppConfig {

    static let appStoreID = "6819992214"

    static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    static let revenueCatAPIKey = "appl_ZLMuUcMIyYyXuKULDChoaMhxwMq"

    /// OneSignal App ID from Dashboard > Settings > Keys & IDs. Leave empty until set.
    static let oneSignalAppID = "28ccee65-88bf-47d6-8c3a-f8bca1e98f57"

    static let privacyPolicyURL = URL(string: "https://example.com/privacy")

    static let termsOfServiceURL = URL(string: "https://example.com/terms")

    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
