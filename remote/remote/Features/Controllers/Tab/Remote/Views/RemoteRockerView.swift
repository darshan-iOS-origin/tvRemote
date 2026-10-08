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
    /// The up and down keys, so the screen can dim the ones the TV lacks.
    private(set) var keyButtons: [RemoteKeyButton] = []

    /// `topKey` and `bottomKey` repeat while held.
    init(
        top: RemoteKeyButton.Icon,
        topKey: KeyCommand,
        title: String,
        bottom: RemoteKeyButton.Icon,
        bottomKey: KeyCommand,
        onKey: @escaping (KeyCommand) -> Void
    ) {
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

        let topButton = makeKey(icon: top, key: topKey, onKey: onKey)
        let bottomButton = makeKey(icon: bottom, key: bottomKey, onKey: onKey)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            heightAnchor.constraint(equalToConstant: Self.height),
            caption.centerXAnchor.constraint(equalTo: centerXAnchor),
            caption.centerYAnchor.constraint(equalTo: centerYAnchor),
            topButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            topButton.centerYAnchor.constraint(equalTo: topAnchor, constant: Self.topIconCenter),
            bottomButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottomButton.centerYAnchor.constraint(equalTo: topAnchor, constant: Self.bottomIconCenter)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("RemoteRockerView is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.layer.cornerRadius = bounds.width / 2
    }

    private func makeKey(
        icon: RemoteKeyButton.Icon,
        key: KeyCommand,
        onKey: @escaping (KeyCommand) -> Void
    ) -> RemoteKeyButton {
        let button = RemoteKeyButton(
            icon: icon,
            fill: .clear,
            borderWidth: 0,
            width: Self.keySize,
            height: Self.keySize
        )
        button.bind(key, repeats: true, handler: onKey)
        keyButtons.append(button)
        addSubview(button)
        return button
    }
}
