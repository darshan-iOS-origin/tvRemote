import UIKit

extension UIViewController {

    /// iPad only: makes the text that comes from the storyboard `DeviceLayout.padFontScale` times bigger. Text made
    /// in code already goes through `CommonFont`, which scales it, so call this as the FIRST thing after
    /// `super.viewDidLoad()` (before any code-made view exists) to avoid scaling twice. Does nothing on iPhone.
    func scalePadFonts() {
        guard DeviceLayout.isPad else { return }
        Self.scalePadFonts(in: view)
    }

    private static func scalePadFonts(in view: UIView) {
        let scale = DeviceLayout.padFontScale
        func scaled(_ font: UIFont) -> UIFont {
            font.withSize((font.pointSize * scale * 2).rounded() / 2)
        }
        if let label = view as? UILabel {
            label.font = scaled(label.font)
        } else if let button = view as? UIButton, let font = button.titleLabel?.font {
            button.titleLabel?.font = scaled(font)
        } else if let field = view as? UITextField, let font = field.font {
            field.font = scaled(font)
        }
        view.subviews.forEach { scalePadFonts(in: $0) }
    }
}
