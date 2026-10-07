import UIKit

final class NavigationManager {

    static let shared = NavigationManager()

    private init() {}

    private let storyboard = UIStoryboard(name: "Main", bundle: nil)

    func instantiate<T: UIViewController>(_ type: T.Type, id: String? = nil) -> T {
        storyboard.instantiateViewController(withIdentifier: id ?? String(describing: type)) as! T
    }

    func showOnboarding(from navigationController: UINavigationController?, animated: Bool = true) {
        let vc = instantiate(OnboardingVC.self)
        navigationController?.setViewControllers([vc], animated: animated)
    }

    func showScanning(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(ScanningVC(), animated: animated)
    }
}
