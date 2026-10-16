import UIKit

extension UIViewController {

    /// iPad only: makes the text that comes from the storyboard `DeviceLayout.padFontScale` times bigger. Text made
    /// in code already goes through `CommonFont`, which scales it, so call this as the FIRST thing after
    /// `super.viewDidLoad()` (before any code-made view exists) to avoid scaling twice. Does nothing on iPhone.
    func scalePadFonts() {
        guard DeviceLayout.isPad else { return }
        Self.scalePadFonts(in: view)
        Self.scalePadSizes(in: view)
    }

    /// iPad: the fixed widths and heights set in the storyboard (a search box, an image, a button, a placeholder)
    /// are `DeviceLayout.padScale` times bigger too, so they match the bigger text.
    private static func scalePadSizes(in view: UIView) {
        for constraint in view.constraints
        where (constraint.firstAttribute == .width || constraint.firstAttribute == .height)
            && constraint.secondItem == nil && constraint.constant > 0
            && constraint.firstItem === view {
            constraint.constant = DeviceLayout.s(constraint.constant)
        }
        view.subviews.forEach { scalePadSizes(in: $0) }
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
