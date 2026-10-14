import UIKit

/// The premium offer. The banner picture stays fixed at the top and the trial button with the links stays
/// fixed at the bottom; everything between them (title, benefits, plans, the "Cancel anytime" pill) scrolls.
/// The plan cards show the store's prices (`SubscriptionManager`); the button buys the selected plan, and the
/// links restore purchases and open the privacy policy and terms. Built in code; open it with `NavigationManager.showSubscription(from:event:)`.
final class SubscriptionVC: UIViewController {

    /// Runs once this screen has closed (by the X, or after "Premium Activated!"). Set by `IAPFlowManager`
    /// to go on to the next screen; when nil (Settings, a premium feature) the screen just closes.
    var onClose: (() -> Void)?

    /// The buy button: shorter than the other blue buttons on iPad, so the animation is not cut.
    private static let buttonHeight: CGFloat = DeviceLayout.isPad ? DeviceLayout.padSubscriptionButtonHeight : LottieManager.buttonHeight

    /// A design size, times `DeviceLayout.padSubscriptionScale` on iPad (unchanged on iPhone). Text also gets the
    /// general iPad font scale from `CommonFont`.
    private static func pad(_ size: CGFloat) -> CGFloat {
        DeviceLayout.isPad ? size * DeviceLayout.padSubscriptionScale : size
    }

    /// iPhone SE-sized screens (667 pt tall or less): the text and spacing are tightened so the title does not run
    /// under the close button and less has to scroll.
    private static let isCompact: Bool = !DeviceLayout.isPad && UIScreen.main.bounds.height <= 667
    private static func compact(_ regular: CGFloat, _ small: CGFloat) -> CGFloat { isCompact ? small : regular }

    private static let closeSize: CGFloat = pad(40)
    private static let bannerAspect: CGFloat = 250.0 / 393.0
    /// The title always overlaps the bottom of the banner by at least this much...
    private static let minTitleOverlap: CGFloat = 16
    /// ...and by at most this much, when the screen is short and needs the room.
    private static let maxTitleOverlap: CGFloat = DeviceLayout.isPad ? 360 : 150

    private let scrollView = UIScrollView()
    private var contentStack: UIStackView?
    /// The empty space at the top of the scroll content, as tall as the banner less the title overlap.
    private var bannerSpaceHeight: NSLayoutConstraint?
    /// The scroll area starts a little below the close button, so the content never slides under it or the status bar.
    private var scrollTopGap: CGFloat { view.safeAreaInsets.top + 8 + Self.closeSize + 8 }
    private var bannerView: UIImageView?
    private let closeButton = HapticButton(type: .custom)
    private let ctaButton = HapticButton(type: .custom)
    private let weekly = PlanCardView(title: "Weekly", price: "$2.99", perDay: "$0.42 Per Day", trial: "3 Day Free Trial")
    private let yearly = PlanCardView(title: "Yearly", price: "$39.99", perDay: "$0.10 Per Day",
                                      trial: "3 Day Free Trial", ribbon: "SAVE 90%")
    private var selectedPlan: SubscriptionProduct = .yearly
    private var didLogDefaultPlan = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsManager.shared.logScreen(FirebaseEvents.Screen.subscription)
        IAPTracker.screenAppeared(self)
        // The Yearly plan is preselected: log it once, before the user changes anything.
        if !didLogDefaultPlan {
            didLogDefaultPlan = true
            IAPTracker.log(.yearPlanDefault)
        }
    }

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A Remote Config value may have arrived after this screen was built.
        refreshPrices()
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
        // Positions are inside the scroll view, which starts below the close button.
        let lowest = max(bannerHeight - Self.maxTitleOverlap - scrollTopGap, 0)
        let highest = max(bannerHeight - Self.minTitleOverlap - scrollTopGap, lowest)
        let space = min(highest, max(lowest, room))
        if bannerSpaceHeight.constant != space { bannerSpaceHeight.constant = space }
        scrollView.isScrollEnabled = room < lowest
    }

    // MARK: - Layout

    /// iPad: the side margins give way (almost required) to the column's maximum width, so the column stays centred.
    /// iPhone: they stay required, as before.
    private func sideEdge(_ constraint: NSLayoutConstraint) -> NSLayoutConstraint {
        if DeviceLayout.isPad { constraint.priority = UILayoutPriority(999) }
        return constraint
    }

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

        styleCloseButton(closeButton)
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
            sideEdge(bottomBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20)),
            sideEdge(bottomBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20)),
            bottomBar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -(DeviceLayout.isPad ? 20 : 8)),

            // The scroll view sits over the banner, below the close button, so the content scrolls over the
            // picture but is clipped before it reaches the button and the status bar.
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            bannerSpace.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            bannerSpace.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            bannerSpace.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
            spaceHeight,

            content.topAnchor.constraint(equalTo: bannerSpace.bottomAnchor),
            sideEdge(content.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 20)),
            sideEdge(content.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -20)),
            content.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -8),

            closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: Self.closeSize),
            closeButton.heightAnchor.constraint(equalToConstant: Self.closeSize)
        ])
        LottieManager.applyButtonBackground(to: ctaButton, height: Self.buttonHeight)
        if DeviceLayout.isPad {
            // iPad: the text, the plans, the button and the links form one centred column, not a left-hugging block.
            let column = DeviceLayout.padSubscriptionColumnWidth
            for item in [content, bottomBar] {
                let maxWidth = item.widthAnchor.constraint(lessThanOrEqualToConstant: column)
                maxWidth.isActive = true
                item.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            }
        }
    }

    /// "Unlock" with the crown, "Your Premium" in a gradient, the tagline, the benefits, the two plans and
    /// the "Cancel anytime" pill.
    private func makeContent() -> UIStackView {
        let unlock = UILabel()
        unlock.text = "Unlock"
        unlock.font = CommonFont.black.font(ofSize: Self.pad(Self.compact(38, 32)))
        unlock.textColor = CommonColor.white.color
        let crown = UIImageView(image: UIImage(named: "crown_frame"))
        crown.contentMode = .scaleAspectFit
        crown.setContentHuggingPriority(.required, for: .horizontal)
        let unlockRow = UIStackView(arrangedSubviews: [unlock, crown, UIView()])
        unlockRow.alignment = .center
        unlockRow.spacing = 12

        let premium = GradientLabel(colors: [UIColor(hex: 0x00CFFE), UIColor(hex: 0x004BF9)])
        premium.font = CommonFont.black.font(ofSize: Self.pad(Self.compact(38, 32)))
        premium.text = "Your Premium"
        let premiumRow = UIStackView(arrangedSubviews: [premium, UIView()])
        premiumRow.alignment = .center

        let tagline = UILabel()
        tagline.text = "More Features for Better Experience"
        tagline.font = CommonFont.medium.font(ofSize: Self.pad(15))
        tagline.textColor = CommonColor.secondaryGray.color

        let features = UIStackView(arrangedSubviews: [
            makeFeature(icon: "feat_1", text: "Instant TV Connection"),
            makeFeature(icon: "feat_2", text: "Cast All Media to TV"),
            makeFeature(icon: "feat_3", text: "Access All Premium Features"),
            makeFeature(icon: "feat_4", text: "Ad-Free Experience")
        ])
        features.axis = .vertical
        features.spacing = Self.pad(Self.compact(16, 10))

        weekly.addAction(UIAction { [weak self] _ in self?.userSelected(self?.weekly) }, for: .touchUpInside)
        yearly.addAction(UIAction { [weak self] _ in self?.userSelected(self?.yearly) }, for: .touchUpInside)
        let plans = PlanCardView.makePlansRow(weekly, yearly, fullWidth: true)

        let pill = makeInfoPill()
        let pillRow = UIStackView(arrangedSubviews: [UIView(), pill, UIView()])
        pillRow.distribution = .equalCentering
        pill.widthAnchor.constraint(lessThanOrEqualTo: pillRow.widthAnchor).isActive = true

        let stack = UIStackView(arrangedSubviews: [unlockRow, premiumRow, tagline, features, plans, pillRow])
        stack.axis = .vertical
        stack.spacing = 0
        stack.setCustomSpacing(Self.pad(4), after: unlockRow)
        stack.setCustomSpacing(Self.pad(8), after: premiumRow)
        stack.setCustomSpacing(Self.pad(Self.compact(24, 14)), after: tagline)
        stack.setCustomSpacing(Self.pad(Self.compact(28, 16)), after: features)
        stack.setCustomSpacing(Self.pad(Self.compact(16, 10)), after: plans)
        return stack
    }

    private func makeFeature(icon: String, text: String) -> UIView {
        let image = UIImageView(image: UIImage(named: icon))
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: Self.pad(36)),
            image.heightAnchor.constraint(equalToConstant: Self.pad(36))
        ])
        let label = UILabel()
        label.text = text
        label.font = CommonFont.semibold.font(ofSize: Self.pad(16))
        label.textColor = CommonColor.white.color
        label.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [image, label])
        row.alignment = .center
        row.spacing = Self.pad(16)
        return row
    }

    /// "• Auto renewable  • Cancel anytime  • No hidden Charges" in a small dark pill.
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
            label.font = CommonFont.medium.font(ofSize: Self.pad(11))
            label.textColor = UIColor(hex: 0x707A91)
            // Three items are tight on a small phone: shrink the text rather than cut it.
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let row = UIStackView(arrangedSubviews: [dot, label])
            row.alignment = .center
            row.spacing = 5
            return row
        }
        let row = UIStackView(arrangedSubviews: [item("Auto renewable"), item("Cancel anytime"), item("No hidden Charges")])
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let pill = UIView()
        pill.backgroundColor = UIColor(hex: 0x10182C)
        pill.layer.cornerRadius = Self.pad(16)
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor(hex: 0x202A40).cgColor
        pill.addSubview(row)
        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: Self.pad(32)),
            row.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            row.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12)
        ])
        return pill
    }

    /// The trial button and the three small links, fixed under the scroll area.
    private func makeBottomBar() -> UIStackView {
        ctaButton.setTitle("3 Day Free Trial", for: .normal)
        ctaButton.setTitleColor(CommonColor.white.color, for: .normal)
        ctaButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        ctaButton.backgroundColor = UIColor(hex: 0x004BF9)
        ctaButton.heightAnchor.constraint(equalToConstant: Self.buttonHeight).isActive = true
        ctaButton.addTarget(self, action: #selector(onTap_trial), for: .touchUpInside)

        let links = makeLegalLinks { [weak self] in self?.close() }

        let stack = UIStackView(arrangedSubviews: [ctaButton, links])
        stack.axis = .vertical
        stack.spacing = Self.compact(14, 8)
        return stack
    }

    // MARK: - Actions

    private func userSelected(_ card: PlanCardView?) {
        guard let card else { return }
        HapticManager.trigger(.light)
        let newPlan: SubscriptionProduct = card === weekly ? .weekly : .yearly
        let changed = newPlan != selectedPlan
        select(card)
        if changed { IAPTracker.log(newPlan == .weekly ? .weekPlanChange : .yearPlanChange) }
    }

    private func select(_ card: PlanCardView) {
        weekly.setSelectedStyle(card === weekly)
        yearly.setSelectedStyle(card === yearly)
        selectedPlan = card === weekly ? .weekly : .yearly
        updateButtonTitle()
    }

    /// Puts the store's prices on the cards once the products are loaded, and shows or hides each plan's
    /// free-trial box from the Remote Config switches (`FreeTrialPolicy`).
    @objc private func refreshPrices() {
        if let display = SubscriptionManager.shared.display(for: .weekly) {
            weekly.update(price: display.price, perDay: display.perDay, trial: display.trial)
        }
        if let display = SubscriptionManager.shared.display(for: .yearly) {
            yearly.update(price: display.price, perDay: display.perDay, trial: display.trial)
        }
        weekly.setTrial(FreeTrialPolicy.text(for: .weekly))
        yearly.setTrial(FreeTrialPolicy.text(for: .yearly))
        updateButtonTitle()
    }

    /// "3 Day Free Trial" while the selected plan shows a trial, otherwise "Continue".
    private func updateButtonTitle() {
        ctaButton.setTitle(FreeTrialPolicy.buttonTitle(for: selectedPlan), for: .normal)
    }

    @objc private func onTap_close() {
        IAPTracker.log(.closeMain)
        close()
    }

    private func close() {
        // Inside the IAP chain `onClose` decides: the next screen opens on top of this one, and the
        // last close dismisses the whole stack. Opened alone, this screen dismisses itself.
        if let onClose {
            onClose()
        } else {
            IAPTracker.end()
            dismiss(animated: true)
        }
    }

    /// Buys the selected plan; "Premium Activated!" closes this screen too.
    @objc private func onTap_trial() {
        startPurchase(of: selectedPlan) { [weak self] in self?.close() }
    }
}
