import UIKit

/// A view with a two-tone gradient border (top-leading to bottom-trailing).
/// It follows `layer.cornerRadius`, so set that (or the `cornerRadius` runtime attribute) as usual.
class GradientBorderView: UIView {

    var borderColors: [UIColor] = [UIColor(hex: 0x434F68), UIColor(hex: 0x1B2434)] {
        didSet { updateBorder() }
    }
    var gradientBorderWidth: CGFloat = 1.5 {
        didSet { updateBorder() }
    }

    private let gradientLayer = CAGradientLayer()
    private let maskLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        maskLayer.fillColor = UIColor.clear.cgColor
        maskLayer.strokeColor = UIColor.black.cgColor
        gradientLayer.mask = maskLayer
        layer.addSublayer(gradientLayer)
        updateBorder()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBorder()
    }

    private func updateBorder() {
        gradientLayer.frame = bounds
        gradientLayer.colors = borderColors.map(\.cgColor)
        maskLayer.lineWidth = gradientBorderWidth
        let inset = gradientBorderWidth / 2
        maskLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset),
            cornerRadius: max(layer.cornerRadius - inset, 0)
        ).cgPath
    }
}
