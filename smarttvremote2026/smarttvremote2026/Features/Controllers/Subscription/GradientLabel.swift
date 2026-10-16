import UIKit

/// A label whose letters are filled with a gradient instead of a flat color (left to right by default).
final class GradientLabel: UIView {

    override class var layerClass: AnyClass { CAGradientLayer.self }

    /// Gives the view its size; its text is also what the gradient shows through.
    private let sizingLabel = UILabel()
    private let maskLabel = UILabel()

    var text: String? {
        didSet {
            sizingLabel.text = text
            maskLabel.text = text
        }
    }

    var font: UIFont = CommonFont.regular.font(ofSize: 17) {
        didSet {
            sizingLabel.font = font
            maskLabel.font = font
        }
    }

    init(colors: [UIColor]) {
        super.init(frame: .zero)
        if let gradient = layer as? CAGradientLayer {
            gradient.colors = colors.map(\.cgColor)
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
        }
        sizingLabel.alpha = 0
        sizingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sizingLabel)
        NSLayoutConstraint.activate([
            sizingLabel.topAnchor.constraint(equalTo: topAnchor),
            sizingLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            sizingLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            sizingLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        // Only the letters of the mask let the gradient through.
        maskLabel.textColor = .black
        mask = maskLabel
    }

    required init?(coder: NSCoder) {
        fatalError("GradientLabel is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        maskLabel.frame = bounds
    }
}
