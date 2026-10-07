import UIKit

class SplashVC: UIViewController {

    private let splashDelay: TimeInterval = 2.0

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()

        DispatchQueue.main.asyncAfter(deadline: .now() + splashDelay) { [weak self] in
            NavigationManager.shared.showOnboarding(from: self?.navigationController)
        }
    }

}
