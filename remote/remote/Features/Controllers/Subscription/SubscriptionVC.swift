import UIKit

/// The premium offer. The banner picture stays fixed at the top and the trial button with the links stays
/// fixed at the bottom; everything between them (title, benefits, plans, the "Cancel anytime" pill) scrolls.
/// The plan cards show the store's prices (`SubscriptionManager`); the button buys the selected plan, and the
/// links restore purchases and open the privacy policy and terms. Built in code; open it with `NavigationManager.showSubscription(from:)`.
final class SubscriptionVC: UIViewController {

    private static let bannerAspect: CGFloat = 250.0 / 393.0
    /// The title always overlaps the bottom of the banner by at least this much...
    private static let minTitleOverlap: CGFloat = 16
    /// ...and by at most this much, when the screen is short and needs the room.
    private static let maxTitleOverlap: CGFloat = 150

    private let scrollView = UIScrollView()
    private var contentStack: UIStackView?
    /// The empty space at the top of the scroll content, as tall as the banner less the title overlap.
    private var bannerSpaceHeight: NSLayoutConstraint?
    private var bannerView: UIImageView?
    private let closeButton = HapticButton(type: .custom)
    private let ctaButton = HapticButton(type: .custom)
    private let monthly = PlanCardView(title: "Monthly", price: "$2.99", perDay: "$0.42 Per Day", trial: "3 Day Free Trial")
    private let yearly = PlanCardView(title: "Yearly", price: "$39.99", perDay: "$0.10 Per Day",
                                      trial: "3 Day Free Trial", ribbon: "SAVE 90%")
    private var selectedPlan: SubscriptionProduct = .yearly

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
        select(yearly)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshPrices), name: SubscriptionManager.productsDidLoadNotification, object: nil
        )
        refreshPrices()
        if !SubscriptionManager.shared.hasProducts {
            Task { await SubscriptionManager.shared.loadProducts() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        closeButton.updateGlassFallbackCorners()
        fitContentToScreen()
    }

    /// Moves the title up over the banner just enough for everything to fit without scrolling. Only when
    /// even the largest overlap is not enough (a small phone, or large text) does the screen scroll.
    private func fitContentToScreen() {
        guard let contentStack, let bannerView, let bannerSpaceHeight, scrollView.bounds.height > 0 else { return }
        let contentHeight = contentStack.systemLayoutSizeFitting(
            CGSize(width: view.bounds.width - 40, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let bannerHeight = bannerView.bounds.height
        // Room left for the empty space above the title: the scroll area minus the content and its 8pt gap.
        let room = scrollView.bounds.height - contentHeight - 8
        let lowest = max(bannerHeight - Self.maxTitleOverlap, 0)
        let highest = max(bannerHeight - Self.minTitleOverlap, lowest)
        let space = min(highest, max(lowest, room))
        if bannerSpaceHeight.constant != space { bannerSpaceHeight.constant = space }
        scrollView.isScrollEnabled = room < lowest
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
        scrollView.alwaysBounceVertical = false

        let bottomBar = makeBottomBar()
        [scrollView, bottomBar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let content = makeContent()
        contentStack = content
        bannerView = banner
        content.translatesAutoresizingMaskIntoConstraints = false
        // An empty header as tall as the banner (less the overlap): the content starts below the banner,
        // and when it scrolls it moves up over the banner.
        let bannerSpace = UIView()
        bannerSpace.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(bannerSpace)
        scrollView.addSubview(content)

        closeButton.setImage(IconsHelper.image(systemName: "xmark", pointSize: 14), for: .normal)
        closeButton.tintColor = CommonColor.white.color
        closeButton.applyGlassStyle()
        closeButton.accessibilityLabel = "Close"
        closeButton.addTarget(self, action: #selector(onTap_close), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        let spaceHeight = bannerSpace.heightAnchor.constraint(equalToConstant: 200)
        bannerSpaceHeight = spaceHeight

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

            // The scroll view covers the banner too, so the content scrolls over the picture.
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            bannerSpace.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            bannerSpace.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            bannerSpace.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
            spaceHeight,

            content.topAnchor.constraint(equalTo: bannerSpace.bottomAnchor),
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

        let links = makeLegalLinks { [weak self] in self?.dismiss(animated: true) }

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
        selectedPlan = card === monthly ? .monthly : .yearly
        updateButtonTitle()
    }

    /// Puts the store's prices on the cards once the products are loaded.
    @objc private func refreshPrices() {
        if let display = SubscriptionManager.shared.display(for: .monthly) {
            monthly.update(price: display.price, perDay: display.perDay, trial: display.trial)
        }
        if let display = SubscriptionManager.shared.display(for: .yearly) {
            yearly.update(price: display.price, perDay: display.perDay, trial: display.trial)
        }
        updateButtonTitle()
    }

    /// "3 Day Free Trial" while the chosen plan has a trial the user can still use, otherwise "Continue".
    private func updateButtonTitle() {
        let trial = SubscriptionManager.shared.display(for: selectedPlan)?.trial
        ctaButton.setTitle(trial == nil && SubscriptionManager.shared.hasProducts ? "Continue" : "3 Day Free Trial", for: .normal)
    }

    /// Closing the offer screen shows the special offer, over the screen this one was opened from.
    @objc private func onTap_close() {
        let presenter = presentingViewController
        // A Premium user has no use for the offer.
        let showsOffer = !SubscriptionManager.shared.isPremium
        dismiss(animated: true) {
            guard showsOffer else { return }
            let offer = OfferSubscriptionVC()
            offer.modalPresentationStyle = .fullScreen
            presenter?.present(offer, animated: true)
        }
    }

    /// Buys the selected plan; "Premium Activated!" closes this screen too.
    @objc private func onTap_trial() {
        startPurchase(of: selectedPlan) { [weak self] in self?.dismiss(animated: true) }
    }
}
