import UIKit

extension UIColor {
    /// Creates a color from a 6-digit hex value, e.g. `0x111E41`.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Dark background with a soft radial glow at the top edge (#111E41 fading into #000312).
final class GradientBackgroundView: UIView {

    static let glowColor = UIColor(hex: 0x111E41)
    static let baseColor = UIColor(hex: 0x000312)

    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false
        backgroundColor = Self.baseColor
        guard let gradient = layer as? CAGradientLayer else { return }
        gradient.type = .radial
        gradient.colors = [Self.glowColor.cgColor, Self.baseColor.cgColor]
        gradient.locations = [0, 1]
        // Centre at the top edge; the end point sets the horizontal and vertical radius.
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 1.0, y: 0.45)
    }
}

extension UIViewController {

    /// Adds the top radial gradient behind everything in `view`. Call it manually, e.g. in
    /// `viewDidLoad`. Safe to call more than once.
    func applyGradientBackground() {
        view.subviews.compactMap { $0 as? GradientBackgroundView }.forEach { $0.removeFromSuperview() }
        view.backgroundColor = GradientBackgroundView.baseColor

        let background = GradientBackgroundView()
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
