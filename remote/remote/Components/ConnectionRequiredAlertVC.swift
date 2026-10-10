import UIKit

/// "Connection Required" dialog shown when an app is tapped while no TV is connected.
/// Presented over the whole screen with a dimmed backdrop. Tapping the backdrop counts as "Maybe Later".
final class ConnectionRequiredAlertVC: UIViewController {

    /// Called after the dialog has gone away, when the user taps Connect.
    var onConnect: (() -> Void)?
    /// Called after the dialog has gone away, when the user taps Maybe Later or the backdrop.
    var onLater: (() -> Void)?

    private static let boxColor = UIColor(hex: 0x10182C)
    private static let mutedColor = UIColor(hex: 0x707A91)
    private static let blueColor = UIColor(hex: 0x004BF9)

    private let backdropView = UIView()
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
        view.backgroundColor = .clear
        setupBackdrop()
        setupCard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: cardView)
    }

    // MARK: - Layout

    private func setupBackdrop() {
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap_later)))
        view.addSubview(backdropView)
        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupCard() {
        cardView.backgroundColor = Self.boxColor
        cardView.layer.cornerRadius = 30
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let iconView = UIImageView(image: Self.icon())
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Self.blueColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Connection Required"
        titleLabel.font = CommonFont.bold.font(ofSize: 20)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = "There is no device connected right now.\nWould you like to connect?"
        messageLabel.font = CommonFont.regular.font(ofSize: 14)
        messageLabel.textColor = Self.mutedColor
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let connectButton = HapticButton(type: .custom)
        connectButton.setTitle("Connect", for: .normal)
        connectButton.setTitleColor(CommonColor.white.color, for: .normal)
        connectButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        connectButton.backgroundColor = Self.blueColor
        connectButton.layer.cornerRadius = 26
        connectButton.addTarget(self, action: #selector(onTap_connect), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false

        let laterButton = HapticButton(type: .custom)
        laterButton.setTitle("Maybe Later", for: .normal)
        laterButton.setTitleColor(Self.mutedColor, for: .normal)
        laterButton.titleLabel?.font = CommonFont.medium.font(ofSize: 16)
        laterButton.addTarget(self, action: #selector(onTap_later), for: .touchUpInside)
        laterButton.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 15

        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack, connectButton, laterButton])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 15
        contentStack.setCustomSpacing(30, after: textStack)
        contentStack.setCustomSpacing(0, after: connectButton)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        // 353pt wide on a phone (20pt side margins); capped so it stays a dialog on iPad.
        let sideMargin = cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        sideMargin.priority = .defaultHigh
        let trailingMargin = cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        trailingMargin.priority = .defaultHigh

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 353),
            sideMargin,
            trailingMargin,

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 30),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 23),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -23),

            iconView.heightAnchor.constraint(equalToConstant: DeviceLayout.s(91.67)),
            connectButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(52)),
            laterButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44))
        ])
        LottieManager.applyButtonBackground(to: connectButton)
    }

    /// The casting illustration from the design, or a symbol if the asset is missing.
    private static func icon() -> UIImage? {
        UIImage(named: "no_connected")
            ?? IconsHelper.image(systemName: "tv.and.mediabox", pointSize: 64)
    }

    // MARK: - Actions

    @objc private func onTap_connect() {
        dismiss(animated: true) { [onConnect] in onConnect?() }
    }

    @objc private func onTap_later() {
        dismiss(animated: true) { [onLater] in onLater?() }
    }
}
