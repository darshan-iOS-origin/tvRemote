import UIKit

/// The premium offer. The banner picture stays fixed at the top and the trial button with the links stays
/// fixed at the bottom; everything between them (title, benefits, plans, the "Cancel anytime" pill) scrolls.
/// UI only for now: nothing is bought. The trial button shows the "Premium Activated!" screen, and the links do nothing yet.
/// Built in code; open it with `NavigationManager.showSubscription(from:)`.
final class SubscriptionVC: UIViewController {

    private static let bannerAspect: CGFloat = 250.0 / 393.0
    /// How far the title overlaps the bottom of the banner.
    private static let titleOverlap: CGFloat = 16

    private let scrollView = UIScrollView()
    private let closeButton = HapticButton(type: .custom)
    private let ctaButton = HapticButton(type: .custom)
    private let monthly = PlanCardView(title: "Monthly", price: "$2.99", perDay: "$0.42 Per Day", trial: "3 Day Free Trial")
    private let yearly = PlanCardView(title: "Yearly", price: "$39.99", perDay: "$0.10 Per Day",
                                      trial: "3 Day Free Trial", ribbon: "SAVE 90%")

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
        select(yearly)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        closeButton.updateGlassFallbackCorners()
    }

    // MARK: - Layout

    private func setupViews() {
        let banner = UIImageView(image: UIImage(named: "top_banner"))
        banner.contentMode = .scaleAspectFill
        banner.clipsToBounds = true
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let bottomBar = makeBottomBar()
        [scrollView, bottomBar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let content = makeContent()
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        closeButton.setImage(IconsHelper.image(systemName: "xmark", pointSize: 14), for: .normal)
        closeButton.tintColor = CommonColor.white.color
        closeButton.applyGlassStyle()
        closeButton.accessibilityLabel = "Close"
        closeButton.addTarget(self, action: #selector(onTap_close), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        let guide = view.safeAreaLayoutGuide
        let frame = scrollView.frameLayoutGuide
        let contentGuide = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            // Fixed at the very top, running under the status bar.
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalTo: banner.widthAnchor, multiplier: Self.bannerAspect),

            // Fixed at the bottom.
            bottomBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            bottomBar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),

            // The scrolling part sits between them; the title overlaps the bottom of the banner a little.
            scrollView.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: -Self.titleOverlap),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            content.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -8),

            closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        LottieManager.applyButtonBackground(to: ctaButton)
    }

    /// "Unlock" with the crown, "Your Premium" in a gradient, the tagline, the benefits, the two plans and
    /// the "Cancel anytime" pill.
    private func makeContent() -> UIStackView {
        let unlock = UILabel()
        unlock.text = "Unlock"
        unlock.font = CommonFont.black.font(ofSize: 38)
        unlock.textColor = CommonColor.white.color
        let crown = UIImageView(image: UIImage(named: "crown_frame"))
        crown.contentMode = .scaleAspectFit
        crown.setContentHuggingPriority(.required, for: .horizontal)
        let unlockRow = UIStackView(arrangedSubviews: [unlock, crown, UIView()])
        unlockRow.alignment = .center
        unlockRow.spacing = 12

        let premium = GradientLabel(colors: [UIColor(hex: 0x00CFFE), UIColor(hex: 0x004BF9)])
        premium.font = CommonFont.black.font(ofSize: 38)
        premium.text = "Your Premium"
        let premiumRow = UIStackView(arrangedSubviews: [premium, UIView()])
        premiumRow.alignment = .center

        let tagline = UILabel()
        tagline.text = "More Features for Better Experience"
        tagline.font = CommonFont.medium.font(ofSize: 15)
        tagline.textColor = CommonColor.secondaryGray.color

        let features = UIStackView(arrangedSubviews: [
            makeFeature(icon: "feat_1", text: "Instant TV Connection"),
            makeFeature(icon: "feat_2", text: "Cast All Media to TV"),
            makeFeature(icon: "feat_3", text: "Access All Premium Features"),
            makeFeature(icon: "feat_4", text: "Ad-Free Experience")
        ])
        features.axis = .vertical
        features.spacing = 16

        monthly.addAction(UIAction { [weak self] _ in self?.userSelected(self?.monthly) }, for: .touchUpInside)
        yearly.addAction(UIAction { [weak self] _ in self?.userSelected(self?.yearly) }, for: .touchUpInside)
        let plans = UIStackView(arrangedSubviews: [monthly, yearly])
        plans.spacing = 16
        plans.distribution = .fillEqually

        let pill = makeInfoPill()
        let pillRow = UIStackView(arrangedSubviews: [UIView(), pill, UIView()])
        pillRow.distribution = .equalCentering

        let stack = UIStackView(arrangedSubviews: [unlockRow, premiumRow, tagline, features, plans, pillRow])
        stack.axis = .vertical
        stack.spacing = 0
        stack.setCustomSpacing(4, after: unlockRow)
        stack.setCustomSpacing(8, after: premiumRow)
        stack.setCustomSpacing(24, after: tagline)
        stack.setCustomSpacing(28, after: features)
        stack.setCustomSpacing(16, after: plans)
        return stack
    }

    private func makeFeature(icon: String, text: String) -> UIView {
        let image = UIImageView(image: UIImage(named: icon))
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 36),
            image.heightAnchor.constraint(equalToConstant: 36)
        ])
        let label = UILabel()
        label.text = text
        label.font = CommonFont.semibold.font(ofSize: 16)
        label.textColor = CommonColor.white.color
        label.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [image, label])
        row.alignment = .center
        row.spacing = 16
        return row
    }

    /// "• Cancel anytime  • No hidden Charges" in a small dark pill.
    private func makeInfoPill() -> UIView {
        func item(_ text: String) -> UIStackView {
            let dot = UIView()
            dot.backgroundColor = UIColor(hex: 0x707A91)
            dot.layer.cornerRadius = 3
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 6),
                dot.heightAnchor.constraint(equalToConstant: 6)
            ])
            let label = UILabel()
            label.text = text
            label.font = CommonFont.medium.font(ofSize: 11)
            label.textColor = UIColor(hex: 0x707A91)
            let row = UIStackView(arrangedSubviews: [dot, label])
            row.alignment = .center
            row.spacing = 6
            return row
        }
        let row = UIStackView(arrangedSubviews: [item("Cancel anytime"), item("No hidden Charges")])
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false

        let pill = UIView()
        pill.backgroundColor = UIColor(hex: 0x10182C)
        pill.layer.cornerRadius = 16
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor(hex: 0x202A40).cgColor
        pill.addSubview(row)
        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: 32),
            row.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            row.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -14)
        ])
        return pill
    }

    /// The trial button and the three small links, fixed under the scroll area.
    private func makeBottomBar() -> UIStackView {
        ctaButton.setTitle("3 Day Free Trial", for: .normal)
        ctaButton.setTitleColor(CommonColor.white.color, for: .normal)
        ctaButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        ctaButton.backgroundColor = UIColor(hex: 0x004BF9)
        ctaButton.heightAnchor.constraint(equalToConstant: LottieManager.buttonHeight).isActive = true
        ctaButton.addTarget(self, action: #selector(onTap_trial), for: .touchUpInside)

        func link(_ title: String) -> UIButton {
            let button = HapticButton(type: .custom)
            button.setAttributedTitle(NSAttributedString(string: title, attributes: [
                .font: CommonFont.medium.font(ofSize: 11),
                .foregroundColor: UIColor(hex: 0x707A91),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]), for: .normal)
            return button
        }
        let links = UIStackView(arrangedSubviews: [link("Privacy Policy"), link("Restore Purchase"), link("Terms of Service")])
        links.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [ctaButton, links])
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }

    // MARK: - Actions

    private func userSelected(_ card: PlanCardView?) {
        guard let card else { return }
        HapticManager.trigger(.light)
        select(card)
    }

    private func select(_ card: PlanCardView) {
        monthly.setSelectedStyle(card === monthly)
        yearly.setSelectedStyle(card === yearly)
    }

    @objc private func onTap_close() {
        dismiss(animated: true)
    }

    /// UI only for now: the trial button just shows the "Premium Activated!" screen, and closing that
    /// closes this screen too.
    @objc private func onTap_trial() {
        let activated = PremiumActivatedVC()
        activated.onDone = { [weak self] in self?.dismiss(animated: true) }
        present(activated, animated: true)
    }
}
