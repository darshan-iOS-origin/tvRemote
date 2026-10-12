import UIKit

/// Analytics for everything that happens inside the IAP screens, named with the entry point that opened them:
/// `<entry>_<step>`, e.g. `setting_banner_month_plan_change`. The entry comes from the `iap_open_<entry>` event
/// (`FirebaseEvents.IAPEntry`) and stays the same for the whole IAP session, including the first-launch chain
/// Main, Offer, Free Trial. Events carry no parameters. Names are built here and nowhere else; `AnalyticsManager`
/// drops any over 35 characters.
enum IAPTracker {

    enum Step: String {
        /// The Yearly plan is preselected when a plan screen appears.
        case yearPlanDefault = "year_plan_default"
        case monthPlanChange = "month_plan_change"
        case yearPlanChange = "year_plan_change"
        /// The X on each IAP screen has its own event, so the three screens can be told apart.
        case closeMain = "main_close"
        case closeOffer = "offer_close"
        case closeTrial = "trial_close"
        case privacyTap = "privacy_tap"
        case termsTap = "terms_tap"
    }

    /// The purchase steps, logged per IAP screen as `<entry>_<screen>_<step>` (e.g. `scanning_offer_buy_start`);
    /// the screen tag is `main`, `offer` or `trial`.
    enum PurchaseStep: String {
        case start = "buy_start"
        case success = "buy_ok"
        case cancel = "buy_cancel"
        case fail = "buy_fail"
    }

    /// The restore steps, logged per IAP screen like the purchase steps (e.g. `scanning_offer_restore`).
    enum RestoreStep: String {
        case tap = "restore"
        /// The restore unlocked Premium.
        case success = "restored"
        /// Nothing to restore, or it failed.
        case fail = "restore_no"
    }

    private static let openPrefix = "iap_open_"
    private static var entry: String?

    /// The entry point of the IAP session that is open, or nil outside one.
    static var currentEntry: String? { entry }

    /// Starts an IAP session. `event` is the `iap_open_<entry>` name the screen was opened with.
    static func begin(event: String) {
        entry = event.hasPrefix(openPrefix) ? String(event.dropFirst(openPrefix.count)) : event
    }

    /// Ends the IAP session once the last IAP screen is gone.
    static func end() {
        entry = nil
    }

    /// Logs `<entry>_<step>`. Does nothing outside an IAP session.
    @MainActor
    static func log(_ step: Step) {
        guard let entry else { return }
        AnalyticsManager.shared.log("\(entry)_\(step.rawValue)", marksPremium: false)
    }

    /// Logs a purchase step for the IAP screen `screen`. Does nothing outside an IAP session.
    @MainActor
    static func log(_ step: PurchaseStep, from screen: UIViewController) {
        guard let entry else { return }
        AnalyticsManager.shared.log("\(entry)_\(screenTag(screen))_\(step.rawValue)", marksPremium: false)
    }

    /// Logs a restore step for the IAP screen `screen`. Does nothing outside an IAP session.
    @MainActor
    static func log(_ step: RestoreStep, from screen: UIViewController) {
        guard let entry else { return }
        AnalyticsManager.shared.log("\(entry)_\(screenTag(screen))_\(step.rawValue)", marksPremium: false)
    }

    private static func screenTag(_ screen: UIViewController) -> String {
        switch screen {
        case is OfferSubscriptionVC: return "offer"
        case is FreeTrailVC: return "trial"
        default: return "main"
        }
    }
}
