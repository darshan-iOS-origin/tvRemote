import UIKit

extension UIView {

    /// iPad only: a container that holds this view at most `maxWidth` wide, centred, so it is not stretched across
    /// a wide screen (the view still fills the width when the screen is narrower). On iPhone it returns the view
    /// itself. Use the result in place of the view.
    func cappedWidthOnPad(_ maxWidth: CGFloat) -> UIView {
        guard DeviceLayout.isPad else { return self }
        let container = UIView()
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        let fill = widthAnchor.constraint(equalTo: container.widthAnchor)
        fill.priority = .defaultHigh
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
            centerXAnchor.constraint(equalTo: container.centerXAnchor),
            leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            fill
        ])
        return container
    }
}
