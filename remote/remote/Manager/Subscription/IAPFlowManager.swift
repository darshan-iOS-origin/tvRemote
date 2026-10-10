import UIKit

/// Decides which subscription screens follow each other when the user closes one, from the three
/// Firebase Remote Config switches. The fixed order is Main → Offer → Free Trial.
///
/// - `iap_main_screen` true: the Subscription screen is part of the chain.
/// - `iap_year_offer_screen` true: the Offer screen is part of the chain.
/// - Free Trial is the last screen: it ends the chain, and it is also what shows when both of the
///   other switches are false (or when `iap_free_trial_screen` is the only one that is true).
///
/// The chain moves on only from the close (X) button. A purchase or restore that makes the user Premium
/// ends the whole chain. The Settings banner and the premium-feature gates do not use this: they open
/// `SubscriptionVC` alone (`NavigationManager.showSubscription`).
enum IAPFlowManager {

    enum Step: CaseIterable {
        case main, offer, freeTrial
    }

    /// The screens to show, in order, for the current Remote Config values. Never empty.
    static func steps(config: RemoteConfigManager = .shared) -> [Step] {
        var steps: [Step] = []
        if config.isMainScreenEnabled { steps.append(.main) }
        if config.isYearOfferScreenEnabled { steps.append(.offer) }
        // Free Trial is the last screen: it closes the chain when its switch is on, and it is the
        // direct fallback when Main and Offer are both off.
        if config.isFreeTrialScreenEnabled || steps.isEmpty { steps.append(.freeTrial) }
        return steps
    }

    /// Runs the chain over `presenter` and calls `completion` once, when it is over (closed, or the
    /// user became Premium). A Premium user skips it.
    static func present(from presenter: UIViewController, completion: @escaping () -> Void) {
        guard !SubscriptionManager.shared.isPremium else {
            completion()
            return
        }
        show(steps(), at: 0, from: presenter, completion: completion)
    }

    private static func show(_ steps: [Step], at index: Int, from presenter: UIViewController, completion: @escaping () -> Void) {
        guard steps.indices.contains(index), !SubscriptionManager.shared.isPremium else {
            completion()
            return
        }
        let screen = makeScreen(steps[index])
        screen.modalPresentationStyle = .fullScreen
        var closed = false
        // `onClose` runs after the screen has dismissed itself, from the X or after "Premium Activated!".
        let next: () -> Void = {
            guard !closed else { return }
            closed = true
            show(steps, at: index + 1, from: presenter, completion: completion)
        }
        switch screen {
        case let vc as SubscriptionVC: vc.onClose = next
        case let vc as OfferSubscriptionVC: vc.onClose = next
        case let vc as FreeTrailVC: vc.onClose = next
        default: break
        }
        topMost(from: presenter).present(screen, animated: true)
    }

    private static func makeScreen(_ step: Step) -> UIViewController {
        switch step {
        case .main: return SubscriptionVC()
        case .offer: return OfferSubscriptionVC()
        case .freeTrial: return FreeTrailVC()
        }
    }

    private static func topMost(from presenter: UIViewController) -> UIViewController {
        var top = presenter
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
