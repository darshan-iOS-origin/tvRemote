import Foundation

/// Whether the free trial is shown for a plan, and what the buy button says. Only the Remote Config switches
/// `year_free_trial` and `month_free_trial` decide it (the trial is managed by hand, so nothing from the store
/// is compared).
///
/// TRUE: the trial text and box show in the plan card, and the button reads "3 Day Free Trial".
/// FALSE: no text and no box, and the button reads "Continue".
enum FreeTrialPolicy {

    static let trialText = "3 Day Free Trial"

    /// The Remote Config switch for `plan`.
    static func isEnabled(for plan: SubscriptionProduct, config: RemoteConfigManager = .shared) -> Bool {
        switch plan {
        case .monthly: return config.isMonthFreeTrialEnabled
        case .yearly, .yearlyOffer: return config.isYearFreeTrialEnabled
        }
    }

    /// The text for the plan card's trial box, or nil to hide the box.
    static func text(for plan: SubscriptionProduct) -> String? {
        isEnabled(for: plan) ? trialText : nil
    }

    /// The buy button's title for the selected plan.
    static func buttonTitle(for plan: SubscriptionProduct) -> String {
        isEnabled(for: plan) ? trialText : "Continue"
    }
}
