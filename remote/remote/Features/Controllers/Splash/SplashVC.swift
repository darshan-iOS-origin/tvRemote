import Lottie
import UIKit

/// The launch screen: the splash animation fills the whole view once, then:
/// - first launch (until the first-time flow has reached the tabs): the ATT and notification permissions,
///   both answered, then onboarding → scan → subscription screens → tabs;
/// - every later launch: the subscription screens, then the tabs.
class SplashVC: UIViewController {

    /// If the animation can't be loaded, wait this long and move on, so the app never gets stuck here.
    private let fallbackDelay: TimeInterval = 2.0
    private var didFinish = false

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()

        let animation = LottieManager.place(.splash, in: view, loop: .playOnce, contentMode: .scaleAspectFill) { [weak self] _ in
            self?.finish()
        }
        if animation == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + fallbackDelay) { [weak self] in
                self?.finish()
            }
        }
    }

    /// Moves on, once.
    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        if AppSettings.hasCompletedFirstLaunchFlow {
            showReturningUserFlow()
        } else {
            showFirstLaunchFlow()
        }
    }

    /// Asks for ATT, then notifications, and opens onboarding only after both have an answer.
    private func showFirstLaunchFlow() {
        Task { [weak self] in
            await LaunchPermissionManager.requestAll()
            NavigationManager.shared.showOnboarding(from: self?.navigationController)
        }
    }

    /// Waits briefly for the Remote Config switches, shows the subscription screens, then the tabs.
    private func showReturningUserFlow() {
        Task { [weak self] in
            await RemoteConfigManager.shared.fetchAndActivate()
            guard let self else { return }
            IAPFlowManager.present(from: self) { [weak self] in
                NavigationManager.shared.showTabs(from: self?.navigationController)
            }
        }
    }
}
