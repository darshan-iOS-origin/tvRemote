import UIKit

/// The backgrounds the user can pick for the Remote and Keyboard tabs. Index 0 is the app's normal
/// gradient; 1...5 are the photos `theme_1`...`theme_5` in `Assets.xcassets/Theme`.
enum ThemeManager {

    private static let key = "selectedThemeIndex"

    /// Number of choices: the gradient plus the photos.
    static let count = 6

    /// The picture for a theme, or nil for the gradient (index 0).
    static func imageName(for index: Int) -> String? {
        index > 0 ? "theme_\(index)" : nil
    }

    /// The saved choice. 0 (the gradient) until the user applies another.
    static var selectedIndex: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: key)
            return (0..<count).contains(saved) ? saved : 0
        }
        set {
            UserDefaults.standard.set((0..<count).contains(newValue) ? newValue : 0, forKey: key)
        }
    }
}

/// The full-screen picture behind a themed screen: the photo with a light dark layer over it, so keys
/// and text stay easy to read. It remembers which theme it shows.
private final class ThemeBackgroundView: UIView {

    let themeIndex: Int

    init(themeIndex: Int, imageName: String) {
        self.themeIndex = themeIndex
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = GradientBackgroundView.baseColor

        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        let shade = UIView()
        shade.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        [imageView, shade].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
            NSLayoutConstraint.activate([
                $0.topAnchor.constraint(equalTo: topAnchor),
                $0.bottomAnchor.constraint(equalTo: bottomAnchor),
                $0.leadingAnchor.constraint(equalTo: leadingAnchor),
                $0.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("ThemeBackgroundView is built in code")
    }
}

extension UIViewController {

    /// Draws the chosen theme behind everything in `view`. Only the Remote and Keyboard tabs call this;
    /// every other screen keeps `applyGradientBackground()`. Safe to call again and again: it does
    /// nothing when the right background is already there.
    func applyThemeBackground() {
        let index = ThemeManager.selectedIndex
        let current = view.subviews.compactMap { $0 as? ThemeBackgroundView }

        guard let imageName = ThemeManager.imageName(for: index) else {
            current.forEach { $0.removeFromSuperview() }
            if !view.subviews.contains(where: { $0 is GradientBackgroundView }) {
                applyGradientBackground()
            }
            return
        }
        if current.contains(where: { $0.themeIndex == index }) { return }

        current.forEach { $0.removeFromSuperview() }
        view.subviews.compactMap { $0 as? GradientBackgroundView }.forEach { $0.removeFromSuperview() }
        view.backgroundColor = GradientBackgroundView.baseColor
        let background = ThemeBackgroundView(themeIndex: index, imageName: imageName)
        background.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(background, at: 0)
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: view.topAnchor),
            background.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
