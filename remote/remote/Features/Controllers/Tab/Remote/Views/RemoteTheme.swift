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
