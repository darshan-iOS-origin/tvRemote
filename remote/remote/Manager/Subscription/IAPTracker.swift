import UIKit

/// Analytics for everything that happens inside the IAP screens, named with the entry point that opened them:
/// `<entry>_<step>`, e.g. `setting_pro_banner_plan_change`. The entry comes from the `iap_open_<entry>` event
/// (`FirebaseEvents.IAPEntry`) and stays the same for the whole IAP session, including the first-launch chain
/// Main, Offer, Free Trial. Names are built here and nowhere else; `AnalyticsManager` drops any over 35 characters.
enum IAPTracker {

    enum Step: String {
        case planChange = "plan_change"
        case purchaseStart = "purchase_start"
        case purchaseSuccess = "purchase_success"
        case purchaseCancel = "purchase_cancel"
        case purchaseFail = "purchase_fail"
        case restoreTap = "restore_tap"
        case restoreSuccess = "restore_success"
        case restoreFail = "restore_fail"
        case close = "iap_close"
        case privacyTap = "privacy_tap"
        case termsTap = "terms_tap"
    }

    private static let openPrefix = "iap_open_"
    private static var entry: String?

    /// Starts an IAP session. `event` is the `iap_open_<entry>` name the screen was opened with.
    static func begin(event: String) {
        entry = event.hasPrefix(openPrefix) ? String(event.dropFirst(openPrefix.count)) : event
    }

    /// Ends the IAP session once the last IAP screen is gone.
    static func end() {
        entry = nil
    }

    /// Logs `<entry>_<step>` with the plan (if any) and the IAP screen it happened on. Does nothing outside an IAP session.
    @MainActor
    static func log(_ step: Step, plan: SubscriptionProduct? = nil, from screen: UIViewController) {
        guard let entry else { return }
        var parameters: [String: Any] = [:]
        if let plan { parameters["plan"] = planName(plan) }
        if let name = screenName(screen) { parameters["screen"] = name }
        AnalyticsManager.shared.log("\(entry)_\(step.rawValue)", parameters: parameters.isEmpty ? nil : parameters)
    }

    private static func planName(_ plan: SubscriptionProduct) -> String {
        switch plan {
        case .monthly: return "monthly"
        case .yearly: return "yearly"
        case .yearlyOffer: return "yearly_offer"
        }
    }

    private static func screenName(_ screen: UIViewController) -> String? {
        switch screen {
        case is SubscriptionVC: return "main"
        case is OfferSubscriptionVC: return "offer"
        case is FreeTrailVC: return "free_trial"
        default: return nil
        }
    }
}
