import UIKit

/// Colours and sizes used only by the Remote screen, taken from the Figma "Remote" frame.
/// Shared colours (blue, white, the dark box) come from `CommonColor`.
enum RemoteTheme {
    /// Fill of every key: #10182C.
    static let box = CommonColor.secondaryDarkGray.color
    static let border = UIColor(hex: 0x434F68)
    static let dpadBorder = UIColor(hex: 0x202A40)
    static let dpadCenter = UIColor(hex: 0x000314)

    /// Blue gradient of the "+" button and the OK key.
    static let blueTop = UIColor(hex: 0x0793FD)
    static let blueBottom = UIColor(hex: 0x0031EA)
    /// Red gradient of the power key.
    static let redTop = UIColor(hex: 0xFC3019)
    static let redBottom = UIColor(hex: 0xDE191C)

    static let keyBorderWidth: CGFloat = 1.5
    /// Gradient border of the keys, top-leading to bottom-trailing: #434F68 into #1B2434.
    static let borderTop = UIColor(hex: 0x434F68)
    static let borderBottom = UIColor(hex: 0x1B2434)
}

/// A gradient ring drawn inside a rounded view's edge. Add it as a sublayer of the view, and call
/// `update(bounds:cornerRadius:width:)` whenever the view lays out.
final class RemoteGradientBorderLayer: CAGradientLayer {

    private let ring = CAShapeLayer()

    override init() {
        super.init()
        setup()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        colors = [RemoteTheme.borderTop.cgColor, RemoteTheme.borderBottom.cgColor]
        startPoint = CGPoint(x: 0, y: 0)
        endPoint = CGPoint(x: 1, y: 1)
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = UIColor.black.cgColor
        mask = ring
    }

    func update(bounds viewBounds: CGRect, cornerRadius: CGFloat, width: CGFloat) {
        frame = viewBounds
        ring.lineWidth = width
        let inset = width / 2
        ring.path = UIBezierPath(
            roundedRect: viewBounds.insetBy(dx: inset, dy: inset),
            cornerRadius: max(cornerRadius - inset, 0)
        ).cgPath
    }
}

extension UIView {

    /// Pins all four edges to `container` (the view must already be in it).
    func pinEdges(to container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}
