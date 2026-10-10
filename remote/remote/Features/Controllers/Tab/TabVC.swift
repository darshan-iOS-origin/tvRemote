import UIKit

class TabVC: UITabBarController {

    /// Titles and icon assets, in the same order as the tab bar controller's view controllers.
    /// Named to avoid `UITabBarController.tabs` (`[UITab]`, iOS 18+).
    private let tabItems: [(title: String, icon: String)] = [
        ("Remote", "tab_1"),
        ("My Apps", "tab_2"),
        ("Keyboard", "tab_3"),
        ("Favourites", "tab_4"),
        ("Settings", "tab_5")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        keepTabBarAtBottom()
        setupTabItems()
        setupTabBarAppearance()
    }

    /// iPad (iPadOS 18 and later) puts the tab bar at the TOP of the screen when the width is regular. The app is
    /// designed with the bar at the bottom, so tell the tab controller (and the screens in it) the width is compact,
    /// the way an iPhone's is. That makes the system draw the usual bottom tab bar. iPhone is not touched.
    private func keepTabBarAtBottom() {
        guard DeviceLayout.isPad else { return }
        if #available(iOS 17.0, *) {
            traitOverrides.horizontalSizeClass = .compact
        }
    }

    private func setupTabItems() {
        guard let controllers = viewControllers else { return }
        for (index, controller) in controllers.enumerated() where index < tabItems.count {
            let tab = tabItems[index]
            controller.tabBarItem = UITabBarItem(title: tab.title, image: UIImage(named: tab.icon), tag: index)
        }
    }

    /// Icons: selected primary blue, others secondary gray. Titles: selected white, others secondary gray.
    private func setupTabBarAppearance() {
        let font = CommonFont.semibold.font(ofSize: 10)

        func style(_ item: UITabBarItemAppearance) {
            item.normal.iconColor = CommonColor.secondaryDarkGray.color
            item.normal.titleTextAttributes = [.font: font, .foregroundColor: CommonColor.secondaryDarkGray.color]
            item.selected.iconColor = CommonColor.primaryBlue.color
            item.selected.titleTextAttributes = [.font: font, .foregroundColor: CommonColor.white.color]
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        style(appearance.stackedLayoutAppearance)
        style(appearance.inlineLayoutAppearance)
        style(appearance.compactInlineLayoutAppearance)

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}

extension TabVC: UITabBarControllerDelegate {

    /// Light haptic when the user switches to a different tab (not when re-tapping the current one).
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if viewController !== tabBarController.selectedViewController {
            HapticManager.trigger(.light)
        }
        return true
    }
}
