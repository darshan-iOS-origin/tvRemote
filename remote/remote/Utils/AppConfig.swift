import Foundation

/// Fixed facts about the app on the App Store. Change them here.
enum AppConfig {

    static let appStoreID = "6819992214"

    static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    // API keys and secrets live in `Secrets.swift` (git-ignored), not here.

    static let privacyPolicyURL = URL(string: "https://sites.google.com/view/tvremote-akash/home")

    static let termsOfServiceURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    /// Apple's page where the user manages or cancels their subscriptions.
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")

    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    /// Debug scan button that connects to a TV by IP. Off until turned on here.
    static let showsAddTVByIP = false
}
