import UIKit

/// "Hold & Tilt for Magic Cursor": explains the LG Remote cursor before it starts. The cursor is only
/// switched on after the user taps Got it (`onGotIt`, called once the dialog has gone away).
final class MagicCursorAlertVC: UIViewController {

    var onGotIt: (() -> Void)?

    private static let boxColor = UIColor(hex: 0x10182C)
    private static let mutedColor = UIColor(hex: 0x707A91)
    private static let blueColor = UIColor(hex: 0x004BF9)

    private let cardView = UIView()

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupCard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: cardView)
    }

    private func setupCard() {
        cardView.backgroundColor = Self.boxColor
        cardView.layer.cornerRadius = 30
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let iconView = UIImageView(image: UIImage(named: "lg_cursor"))
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "Hold & Tilt for Magic Cursor"
        titleLabel.font = CommonFont.bold.font(ofSize: 20)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = "Press and hold while tilting your phone\nto move cursor on TV screen"
        messageLabel.font = CommonFont.regular.font(ofSize: 14)
        messageLabel.textColor = Self.mutedColor
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let gotIt = HapticButton(type: .custom)
        gotIt.setTitle("Got it", for: .normal)
        gotIt.setTitleColor(CommonColor.white.color, for: .normal)
        gotIt.titleLabel?.font = CommonFont.bold.font(ofSize: 18)
        gotIt.backgroundColor = Self.blueColor
        gotIt.layer.cornerRadius = 26
        gotIt.addTarget(self, action: #selector(onTap_gotIt), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.spacing = 8

        let stack = UIStackView(arrangedSubviews: [iconView, textStack, gotIt])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.setCustomSpacing(24, after: textStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)

        let leading = cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        leading.priority = .defaultHigh
        let trailing = cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        trailing.priority = .defaultHigh

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 353),
            leading,
            trailing,

            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            iconView.heightAnchor.constraint(equalToConstant: 100),
            gotIt.heightAnchor.constraint(equalToConstant: 52)
        ])
        LottieManager.applyButtonBackground(to: gotIt)
    }

    @objc private func onTap_gotIt() {
        dismiss(animated: true) { [onGotIt] in onGotIt?() }
    }
}
