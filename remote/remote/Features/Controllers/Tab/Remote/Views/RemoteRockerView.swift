import UIKit

/// A tall pill with an up key, a blue caption and a down key: the VOL and CH controls.
final class RemoteRockerView: UIView {

    static let width: CGFloat = 60
    static let height: CGFloat = 170
    private static let keySize: CGFloat = 60
    /// Centre of the top and bottom icons, measured from the top edge.
    private static let topIconCenter: CGFloat = 35
    private static let bottomIconCenter: CGFloat = 134

    private let surface = UIView()

    init(top: RemoteKeyButton.Icon, title: String, bottom: RemoteKeyButton.Icon) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        surface.isUserInteractionEnabled = false
        surface.backgroundColor = RemoteTheme.box
        surface.clipsToBounds = true
        surface.layer.borderWidth = RemoteTheme.keyBorderWidth
        surface.layer.borderColor = RemoteTheme.border.cgColor
        addSubview(surface)
        surface.pinEdges(to: self)

        let caption = UILabel()
        caption.isUserInteractionEnabled = false
        caption.attributedText = NSAttributedString(string: title, attributes: [
            .font: CommonFont.heavy.font(ofSize: 16),
            .foregroundColor: CommonColor.primaryBlue.color,
            .kern: 0.32
        ])
        caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(caption)

        let topKey = makeKey(icon: top)
        let bottomKey = makeKey(icon: bottom)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            heightAnchor.constraint(equalToConstant: Self.height),
            caption.centerXAnchor.constraint(equalTo: centerXAnchor),
            caption.centerYAnchor.constraint(equalTo: centerYAnchor),
            topKey.centerXAnchor.constraint(equalTo: centerXAnchor),
            topKey.centerYAnchor.constraint(equalTo: topAnchor, constant: Self.topIconCenter),
            bottomKey.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottomKey.centerYAnchor.constraint(equalTo: topAnchor, constant: Self.bottomIconCenter)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("RemoteRockerView is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.layer.cornerRadius = bounds.width / 2
    }

    private func makeKey(icon: RemoteKeyButton.Icon) -> RemoteKeyButton {
        let key = RemoteKeyButton(
            icon: icon,
            fill: .clear,
            borderWidth: 0,
            width: Self.keySize,
            height: Self.keySize
        )
        addSubview(key)
        return key
    }
}
