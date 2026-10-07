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
        setupTabItems()
        setupTabBarAppearance()
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
        let font = UIFont(name: "SFProText-Semibold", size: 10) ?? .systemFont(ofSize: 10, weight: .semibold)

        func style(_ item: UITabBarItemAppearance) {
            item.normal.iconColor = CommonColor.secondaryGray.color
            item.normal.titleTextAttributes = [.font: font, .foregroundColor: CommonColor.secondaryGray.color]
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
