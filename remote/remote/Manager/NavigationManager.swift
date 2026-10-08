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
        navigationController?.pushViewController(instantiate(ScanningVC.self), animated: animated)
    }

    func showTabs(from navigationController: UINavigationController?, animated: Bool = true) {
        let vc = instantiate(TabVC.self)
        navigationController?.setViewControllers([vc], animated: animated)
    }

    func showAddApps(from navigationController: UINavigationController?, onSave: (([StreamingApp]) -> Void)? = nil, animated: Bool = true) {
        let vc = instantiate(AddAppsVC.self)
        vc.onSave = onSave
        navigationController?.pushViewController(vc, animated: animated)
    }

    func showCast(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(CastVC(), animated: animated)
    }

    func showScreenMirror(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(ScreenMirrorVC(), animated: animated)
    }
}
