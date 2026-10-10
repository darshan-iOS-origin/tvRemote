import Foundation

/// Whether the free trial is shown for a plan, and what the buy button says. The Remote Config switches
/// `year_free_trial` and `month_free_trial` decide it; a plan the store says has no trial for this user (the
/// intro offer was already used) never shows one, so the screen never promises what the App Store won't give.
///
/// Shown: the trial text and box in the plan card, and the button reads "3 Day Free Trial".
/// Hidden: no text and no box, and the button reads "Continue".
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
    @MainActor
    static func text(for plan: SubscriptionProduct) -> String? {
        guard isEnabled(for: plan) else { return nil }
        let manager = SubscriptionManager.shared
        guard manager.hasProducts else { return trialText }
        // Products loaded: only show a trial the store really offers this user.
        return manager.display(for: plan)?.trial
    }

    /// The buy button's title for the selected plan.
    @MainActor
    static func buttonTitle(for plan: SubscriptionProduct) -> String {
        text(for: plan) == nil ? "Continue" : trialText
    }
}
