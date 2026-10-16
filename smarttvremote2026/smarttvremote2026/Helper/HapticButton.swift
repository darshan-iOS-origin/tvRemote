import UIKit

/// Base class for every tappable button in the app. Fires a haptic on touch-down
/// so each button gives feedback by default; set `hapticType` to change it, or
/// `nil` to opt out. Use this as the custom class for storyboard buttons.
class HapticButton: UIButton {

    var hapticType: HapticType? = .light

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        addTarget(self, action: #selector(fireHaptic), for: .touchDown)
    }

    @objc private func fireHaptic() {
        guard let hapticType else { return }
        HapticManager.trigger(hapticType)
    }
}

extension UIButton {
    /// For buttons that can't subclass `HapticButton` (e.g. system-created ones).
    func addHaptic(_ type: HapticType = .light) {
        addAction(UIAction { _ in HapticManager.trigger(type) }, for: .touchDown)
    }
}
