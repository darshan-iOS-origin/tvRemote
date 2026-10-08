import Lottie
import UIKit

/// The launch screen: the splash animation fills the whole view once, then onboarding opens.
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

    /// Opens onboarding, once.
    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        NavigationManager.shared.showOnboarding(from: navigationController)
    }
}
