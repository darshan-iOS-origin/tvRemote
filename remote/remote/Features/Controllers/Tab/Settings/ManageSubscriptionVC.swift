import UIKit

/// "Manage Subscription": pick why you want to cancel (one reason at most), then "Cancel Subscription" sends
/// the cancellation request by e-mail (`FeedbackMail.sendCancellation`) and opens Apple's subscriptions page.
/// "Expensive" also shows the special offer to a free user. Built in code; open it with
/// `NavigationManager.showManageSubscription(from:)`.
final class ManageSubscriptionVC: UIViewController {

    private let backButton = HapticButton(type: .custom)
    private let titleLabel = UILabel()
    private let cancelButton = HapticButton(type: .custom)
    private var rows: [ManageSubscriptionOption: HapticButton] = [:]
    private var selected: ManageSubscriptionOption?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsManager.shared.logScreen(FirebaseEvents.Screen.manageSubscription)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
    }

    // MARK: - Layout

    private func setupViews() {
        backButton.applyBackArrowStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)

        titleLabel.text = "Manage Subscription"
        titleLabel.font = CommonFont.semibold.font(ofSize: 18)
        titleLabel.textColor = CommonColor.white.color

        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        for option in ManageSubscriptionOption.allCases {
            let row = makeRow(option)
            rows[option] = row
            stack.addArrangedSubview(row)
        }

        cancelButton.setTitle("Cancel Subscription", for: .normal)
        cancelButton.setTitleColor(CommonColor.white.color, for: .normal)
        cancelButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        cancelButton.backgroundColor = UIColor(hex: 0xC91D1D)
        cancelButton.layer.cornerRadius = DeviceLayout.s(52) / 2
        cancelButton.addTarget(self, action: #selector(onTap_cancel), for: .touchUpInside)

        let note = UILabel()
        note.text = "You can manage or cancel anytime."
        note.font = CommonFont.regular.font(ofSize: 14)
        note.textColor = UIColor(hex: 0x707A91)
        note.textAlignment = .center

        let bottom = UIStackView(arrangedSubviews: [cancelButton, note])
        bottom.axis = .vertical
        bottom.spacing = 12

        [backButton, titleLabel, scrollView, bottom].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            bottom.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            bottom.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            bottom.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
            cancelButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(52)),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16)
        ])
        refreshStyles()
    }

    /// A rounded row: icon, title over subtitle, chevron.
    private func makeRow(_ option: ManageSubscriptionOption) -> HapticButton {
        let row = HapticButton(type: .custom)
        row.layer.cornerRadius = 28
        row.layer.borderWidth = 1.5
        row.accessibilityLabel = "\(option.rawValue), \(option.subtitle)"
        row.accessibilityTraits = .button

        let icon = UIImageView(image: UIImage(named: option.iconName))
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = option.rawValue
        title.font = CommonFont.semibold.font(ofSize: 16)
        title.textColor = CommonColor.white.color
        let subtitle = UILabel()
        subtitle.text = option.subtitle
        subtitle.font = CommonFont.regular.font(ofSize: 12)
        subtitle.textColor = UIColor(hex: 0x707A91)
        let texts = UIStackView(arrangedSubviews: [title, subtitle])
        texts.axis = .vertical
        texts.spacing = 2

        let chevron = UIImageView(image: IconsHelper.image(systemName: "chevron.right", pointSize: 12))
        chevron.tintColor = UIColor(hex: 0x707A91)
        chevron.contentMode = .center

        let content = UIStackView(arrangedSubviews: [icon, texts, UIView(), chevron])
        content.alignment = .center
        content.spacing = 16
        content.isUserInteractionEnabled = false
        content.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(content)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: DeviceLayout.s(58)),
            icon.widthAnchor.constraint(equalToConstant: DeviceLayout.s(26)),
            icon.heightAnchor.constraint(equalToConstant: DeviceLayout.s(26)),
            content.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            content.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        row.addAction(UIAction { [weak self] _ in self?.didTap(option) }, for: .touchUpInside)
        return row
    }

    private func refreshStyles() {
        for (option, row) in rows {
            let isSelected = option == selected
            row.backgroundColor = UIColor(hex: 0x10182C)
            row.layer.borderColor = (isSelected ? UIColor(hex: 0x004BF9) : UIColor.clear).cgColor
            row.accessibilityValue = isSelected ? "Selected" : "Not selected"
        }
    }

    // MARK: - Actions

    @objc private func onTap_back() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.manageSubBack)
        navigationController?.popViewController(animated: true)
    }

    /// One reason at a time. A free user who taps "Expensive" also gets the special offer; "Expensive" stays
    /// selected when the offer is closed, until another reason is tapped.
    private func didTap(_ option: ManageSubscriptionOption) {
        if let event = FirebaseEvents.Tap.manageSubReasons[option.rawValue] { AnalyticsManager.shared.log(event) }
        selected = option
        refreshStyles()
        if option == .expensive, !SubscriptionManager.shared.isPremium {
            let offer = OfferSubscriptionVC()
            offer.modalPresentationStyle = .fullScreen
            present(offer, animated: true)
        }
    }

    @objc private func onTap_cancel() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.manageSubCancel)
        FeedbackMail.sendCancellation(reason: selected?.rawValue, from: self) { [weak self] in
            guard let self else { return }
            self.requireInternet {
                if let url = AppConfig.manageSubscriptionsURL { UIApplication.shared.open(url) }
            }
            self.navigationController?.popViewController(animated: true)
        }
    }
}
