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

    /// `addingTV` is for "+" on the remote screens: the scanning screen gets a back button and returns to
    /// the screen it came from after connecting.
    func showScanning(from navigationController: UINavigationController?, addingTV: Bool = false, animated: Bool = true) {
        let vc = instantiate(ScanningVC.self)
        vc.isAddingTV = addingTV
        navigationController?.pushViewController(vc, animated: animated)
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

    func showVoice(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(VoiceVC(), animated: animated)
    }

    func showCast(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(CastVC(), animated: animated)
    }

    func showScreenMirror(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(ScreenMirrorVC(), animated: animated)
    }

    func showHistory(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(HistoryVC(), animated: animated)
    }

    func showMyTVs(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(MyTVsVC(), animated: animated)
    }

    func showFeedback(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(FeedbackVC(), animated: animated)
    }

    func showAppIcon(from navigationController: UINavigationController?, animated: Bool = true) {
        navigationController?.pushViewController(AppIconVC(), animated: animated)
    }
}
