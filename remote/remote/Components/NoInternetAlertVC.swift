import UIKit

/// "No Internet Connection" dialog, shared by every button that needs the network.
/// Presented over the whole screen with a dimmed backdrop; tapping the backdrop counts as Close.
/// Use it through `requireInternet(then:)` rather than building it directly.
final class NoInternetAlertVC: UIViewController {

    /// Called after the dialog has gone away, when the user taps Try Again and the device is back online.
    var onRetry: (() -> Void)?

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
        view.backgroundColor = .clear
        setupBackdrop()
        setupCard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsManager.shared.logScreen(FirebaseEvents.Screen.noInternetAlert)
        UIAccessibility.post(notification: .screenChanged, argument: cardView)
    }

    // MARK: - Layout

    private func setupBackdrop() {
        let backdropView = UIView()
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap_close)))
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

        let iconView = UIImageView(image: IconsHelper.image(systemName: "wifi.slash", pointSize: 56))
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Self.blueColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "No Internet Connection"
        titleLabel.font = CommonFont.bold.font(ofSize: 20)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = "Please check your Wi-Fi or mobile data\nand try again."
        messageLabel.font = CommonFont.regular.font(ofSize: 14)
        messageLabel.textColor = Self.mutedColor
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let retryButton = HapticButton(type: .custom)
        retryButton.setTitle("Try Again", for: .normal)
        retryButton.setTitleColor(CommonColor.white.color, for: .normal)
        retryButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        retryButton.backgroundColor = Self.blueColor
        retryButton.layer.cornerRadius = 26
        retryButton.addTarget(self, action: #selector(onTap_retry), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = HapticButton(type: .custom)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(Self.mutedColor, for: .normal)
        closeButton.titleLabel?.font = CommonFont.medium.font(ofSize: 16)
        closeButton.addTarget(self, action: #selector(onTap_close), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 15

        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack, retryButton, closeButton])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 15
        contentStack.setCustomSpacing(30, after: textStack)
        contentStack.setCustomSpacing(0, after: retryButton)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        // Same size as the Connection Required dialog: 20pt side margins on a phone, capped on iPad.
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

            iconView.heightAnchor.constraint(equalToConstant: DeviceLayout.s(72)),
            retryButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(52)),
            closeButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44))
        ])
        LottieManager.applyButtonBackground(to: retryButton)
    }

    // MARK: - Actions

    /// Closes the dialog, then runs `onRetry` only if the network is back. If it is still off, the dialog
    /// comes straight back so the user is never left with a button that silently does nothing.
    @objc private func onTap_retry() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.noInternetRetry)
        dismiss(animated: true) { [weak presenter = presentingViewController, onRetry] in
            guard let onRetry else { return }
            presenter?.requireInternet(then: onRetry)
        }
    }

    @objc private func onTap_close() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.noInternetClose)
        dismiss(animated: true)
    }
}

extension UIViewController {

    /// Runs `action` if the device is online. If not, shows the No Internet dialog instead; when the user
    /// taps Try Again and the network is back, `action` runs then. Returns whether `action` ran right away.
    @discardableResult
    func requireInternet(then action: @escaping () -> Void) -> Bool {
        guard NetworkManager.shared.checkConnectivity() else {
            LoggerManager.warning("Network required but device is offline", category: "Network")
            HapticManager.trigger(.error)
            var top = self
            while let presented = top.presentedViewController { top = presented }
            // Already showing it (e.g. a double tap): leave it be.
            guard !(top is NoInternetAlertVC) else { return false }
            let alert = NoInternetAlertVC()
            alert.onRetry = action
            top.present(alert, animated: true)
            return false
        }
        action()
        return true
    }
}
