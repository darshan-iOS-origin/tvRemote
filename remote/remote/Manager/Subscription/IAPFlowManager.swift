import UIKit

/// Decides which subscription screens follow each other when the user closes one, from the three
/// Firebase Remote Config switches. The fixed order is Main → Offer → Free Trial.
///
/// The switches come in two sets: the plain keys apply the first time the user reaches the subscription
/// screens after a fresh install, and the `_second_time` keys (`iap_main_screen_second_time` and so on) every
/// time after that (`AppSettings.hasShownIAPChain`). Opening the app without reaching them does not count, and
/// neither does reaching them without getting to the Remote screen afterwards (`markReachedHome()`).
///
/// - `iap_main_screen` true: the Subscription screen is part of the chain.
/// - `iap_year_offer_screen` true: the Offer screen is part of the chain.
/// - Free Trial is the last screen: it ends the chain, and it is also what shows when both of the
///   other switches are false (or when `iap_free_trial_screen` is the only one that is true).
///
/// The chain moves on only from the top left close button (the X). With a
/// `navigation` controller each next screen is pushed on top of the current one, and the last close just
/// calls `completion` (which replaces the stack, e.g. with the tabs); without one the screens are presented
/// full screen and the last close dismisses them together. A purchase or restore that makes the user Premium
/// ends the whole chain. The Settings banner and the premium-feature gates do not use this: they open
/// `SubscriptionVC` alone (`NavigationManager.showSubscription`).
enum IAPFlowManager {

    enum Step: CaseIterable {
        case main, offer, freeTrial
    }

    /// True once a chain was started in this launch; `markReachedHome()` then makes it count.
    private static var chainShownThisLaunch = false

    /// Call when the Remote screen appears. Only now is the first-time flow done and the subscription screens
    /// counted as seen, so the next chain follows the `_second_time` keys. A launch that stopped before this
    /// point (the app closed on a subscription screen) starts the first-time flow again.
    static func markReachedHome() {
        if chainShownThisLaunch { AppSettings.hasShownIAPChain = true }
        if !AppSettings.hasCompletedFirstLaunchFlow { AppSettings.hasCompletedFirstLaunchFlow = true }
    }

    /// The screens to show, in order, for the current Remote Config values. Never empty.
    static func steps(config: RemoteConfigManager = .shared, isFirstTime: Bool = !AppSettings.hasShownIAPChain) -> [Step] {
        let main = isFirstTime ? config.isMainScreenEnabled : config.isMainScreenEnabledSecondTime
        let offer = isFirstTime ? config.isYearOfferScreenEnabled : config.isYearOfferScreenEnabledSecondTime
        let freeTrial = isFirstTime ? config.isFreeTrialScreenEnabled : config.isFreeTrialScreenEnabledSecondTime
        var steps: [Step] = []
        if main { steps.append(.main) }
        if offer { steps.append(.offer) }
        // Free Trial is the last screen: it closes the chain when its switch is on, and it is the
        // direct fallback when Main and Offer are both off.
        if freeTrial || steps.isEmpty { steps.append(.freeTrial) }
        return steps
    }

    /// Runs the chain and calls `completion` once, when it is over (closed, or the user became Premium). A
    /// Premium user skips it. With `navigation` the screens are pushed onto it (the swipe-back gesture is off
    /// meanwhile); otherwise they are presented over `presenter`.
    /// `event` names what started the chain (`FirebaseEvents.IAPEntry`); it is logged once the first screen opens.
    static func present(from presenter: UIViewController, navigation: UINavigationController? = nil,
                        event: String, completion: @escaping () -> Void) {
        guard !SubscriptionManager.shared.isPremium else {
            completion()
            return
        }
        AnalyticsManager.shared.log(event, marksPremium: false, clarity: true)
        IAPTracker.begin(event: event)
        navigation?.interactivePopGestureRecognizer?.isEnabled = false
        let finish: () -> Void = {
            navigation?.interactivePopGestureRecognizer?.isEnabled = true
            completion()
        }
        let chain = steps()
        // The user is not past the first time until the Remote screen has appeared (`markReachedHome()`). Closing
        // the app in the middle of the chain keeps the first-time keys for the next launch.
        chainShownThisLaunch = true
        show(chain, at: 0, from: presenter, navigation: navigation, completion: finish)
    }

    private static func show(_ steps: [Step], at index: Int, from presenter: UIViewController,
                             navigation: UINavigationController?, completion: @escaping () -> Void) {
        guard steps.indices.contains(index), !SubscriptionManager.shared.isPremium else {
            completion()
            return
        }
        let screen = makeScreen(steps[index])
        var closed = false
        // `onClose` runs from the top left button or after "Premium Activated!", while the screen is still up.
        // The next screen opens on top of it; after the last one (or Premium) the chain ends.
        let next: () -> Void = {
            guard !closed else { return }
            closed = true
            if steps.indices.contains(index + 1), !SubscriptionManager.shared.isPremium {
                show(steps, at: index + 1, from: presenter, navigation: navigation, completion: completion)
            } else {
                IAPTracker.end()
                if navigation != nil {
                    completion()
                } else {
                    presenter.dismiss(animated: true) { completion() }
                }
            }
        }
        switch screen {
        case let vc as SubscriptionVC: vc.onClose = next
        case let vc as OfferSubscriptionVC: vc.onClose = next
        case let vc as FreeTrailVC: vc.onClose = next
        default: break
        }
        if let navigation {
            navigation.pushViewController(screen, animated: true)
        } else {
            screen.modalPresentationStyle = .fullScreen
            topMost(from: presenter).present(screen, animated: true)
        }
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
