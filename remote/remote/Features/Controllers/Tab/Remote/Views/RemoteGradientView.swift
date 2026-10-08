import UIKit

/// A view backed by a `CAGradientLayer`, for the linear and radial gradients of the Remote screen.
final class RemoteGradientView: UIView {

    /// An elliptical gradient. `center` and `end` are in unit coordinates: `end` marks the edge of the ellipse.
    struct Radial {
        let colors: [UIColor]
        let locations: [CGFloat]
        let center: CGPoint
        let end: CGPoint
    }

    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var gradientLayer: CAGradientLayer? { layer as? CAGradientLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
    }

    /// Top to bottom.
    func setLinear(top: UIColor, bottom: UIColor) {
        guard let gradientLayer else { return }
        gradientLayer.type = .axial
        gradientLayer.colors = [top.cgColor, bottom.cgColor]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
    }

    func setRadial(_ radial: Radial) {
        guard let gradientLayer else { return }
        gradientLayer.type = .radial
        gradientLayer.colors = radial.colors.map(\.cgColor)
        gradientLayer.locations = radial.locations.map { NSNumber(value: Double($0)) }
        gradientLayer.startPoint = radial.center
        gradientLayer.endPoint = radial.end
    }
}
