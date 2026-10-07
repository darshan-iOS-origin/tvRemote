import UIKit

extension UIButton {

    /// Gives a round icon button the "liquid glass" look.
    /// iOS 26+: the system glass button configuration. Earlier versions: a blurred, bordered circle.
    func applyGlassStyle() {
        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            configuration.image = image(for: .normal)
            configuration.cornerStyle = .capsule
            configuration.baseForegroundColor = tintColor
            self.configuration = configuration
        } else {
            applyBlurFallback()
        }
    }

    private func applyBlurFallback() {
        let tag = 0x61_6C_61_73   // marks the blur view so repeated calls don't stack views
        guard viewWithTag(tag) == nil else { return }

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.tag = tag
        blur.isUserInteractionEnabled = false
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.clipsToBounds = true
        blur.layer.borderWidth = 1
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        insertSubview(blur, at: 0)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        layoutIfNeeded()
        blur.layer.cornerRadius = bounds.height / 2
        if let imageView { bringSubviewToFront(imageView) }
    }

    /// Keeps the fallback blur circular after layout changes.
    func updateGlassFallbackCorners() {
        if let blur = viewWithTag(0x61_6C_61_73) { blur.layer.cornerRadius = bounds.height / 2 }
    }
}
