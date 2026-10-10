import UIKit

/// "3 Days Free, No Risk": shown after the last onboarding page. A timeline of how the free trial works,
/// the Monthly and Yearly plans with the store's prices, and a "Start 3-Day Free Trial" button that buys the
/// selected plan. `onClose` runs once the screen has closed: by the X, or after "Premium Activated!".
final class FreeTrailVC: UIViewController {

    var onClose: (() -> Void)?

    private static let muted = UIColor(hex: 0x707A91)
    private static let cardColor = UIColor(hex: 0x10182C)
    private static let cardBorder = UIColor(hex: 0x202A40)

    private let closeButton = HapticButton(type: .custom)
    private let startButton = HapticButton(type: .custom)
    private let scrollView = UIScrollView()
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A Remote Config value may have arrived after this screen was built.
        refreshPrices()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        closeButton.updateGlassFallbackCorners()
    }

    // MARK: - Layout

    private func setupViews() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false

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
            closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            bottomBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            bottomBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            bottomBar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            content.topAnchor.constraint(equalTo: contentGuide.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -8)
        ])
        LottieManager.applyButtonBackground(to: startButton)
    }

    /// The two title lines, the line under them, the timeline card and the two plans.
    private func makeContent() -> UIStackView {
        let free = UILabel()
        free.text = "3 Days Free"
        free.font = CommonFont.heavy.font(ofSize: 46)
        free.textColor = CommonColor.white.color
        free.textAlignment = .center
        free.adjustsFontSizeToFitWidth = true
        free.minimumScaleFactor = 0.6

        let noRisk = GradientLabel(colors: [UIColor(hex: 0x00CFFE), UIColor(hex: 0x004BF9)])
        noRisk.font = CommonFont.heavy.font(ofSize: 46)
        noRisk.text = "No Risk"
        let noRiskRow = UIStackView(arrangedSubviews: [UIView(), noRisk, UIView()])
        noRiskRow.distribution = .equalCentering

        let tagline = UILabel()
        tagline.text = "Try every Pro feature free for 3 days."
        tagline.font = CommonFont.regular.font(ofSize: 16)
        tagline.textColor = Self.muted
        tagline.textAlignment = .center
        tagline.numberOfLines = 0

        monthly.addAction(UIAction { [weak self] _ in self?.userSelected(self?.monthly) }, for: .touchUpInside)
        yearly.addAction(UIAction { [weak self] _ in self?.userSelected(self?.yearly) }, for: .touchUpInside)
        let plans = UIStackView(arrangedSubviews: [monthly, yearly])
        plans.spacing = 16
        plans.distribution = .fillEqually

        let timeline = makeTimelineCard()
        let stack = UIStackView(arrangedSubviews: [free, noRiskRow, tagline, timeline, plans])
        stack.axis = .vertical
        stack.spacing = 0
        stack.setCustomSpacing(0, after: free)
        stack.setCustomSpacing(10, after: noRiskRow)
        stack.setCustomSpacing(28, after: tagline)
        stack.setCustomSpacing(24, after: timeline)
        return stack
    }

    /// Three steps with their 40x40 icons, joined by a thin vertical line: blue, then orange.
    private func makeTimelineCard() -> UIView {
        let steps: [(icon: String, title: String, detail: String)] = [
            ("lock", "Get Full Access", "Unlock every Pro feature"),
            ("reminder", "Trial Reminder", "We'll remind you before your trial ends"),
            ("trailEnd", "Trial Ends", "Your Annual Pro plan begins")
        ]
        var icons: [UIImageView] = []
        var rows: [UIView] = []
        for step in steps {
            let icon = UIImageView(image: UIImage(named: step.icon))
            icon.contentMode = .center
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 40),
                icon.heightAnchor.constraint(equalToConstant: 40)
            ])
            icons.append(icon)

            let title = UILabel()
            title.text = step.title
            title.font = CommonFont.bold.font(ofSize: 16)
            title.textColor = CommonColor.white.color
            let detail = UILabel()
            detail.text = step.detail
            detail.font = CommonFont.regular.font(ofSize: 12)
            detail.textColor = Self.muted
            detail.numberOfLines = 0
            let texts = UIStackView(arrangedSubviews: [title, detail])
            texts.axis = .vertical
            texts.spacing = 2

            let row = UIStackView(arrangedSubviews: [icon, texts])
            row.alignment = .center
            row.spacing = 16
            rows.append(row)
        }
        let list = UIStackView(arrangedSubviews: rows)
        list.axis = .vertical
        list.spacing = 22
        list.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = Self.cardColor
        card.layer.cornerRadius = 24
        card.layer.borderWidth = 1
        card.layer.borderColor = Self.cardBorder.cgColor
        card.addSubview(list)
        NSLayoutConstraint.activate([
            list.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            list.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            list.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            list.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20)
        ])

        // The joining lines run from the bottom of one icon to the top of the next, behind nothing.
        let colors = [UIColor(hex: 0x004BF9), UIColor(hex: 0xFF6A1F)]
        for index in 0..<(icons.count - 1) {
            let line = UIView()
            line.backgroundColor = colors[index]
            line.translatesAutoresizingMaskIntoConstraints = false
            card.insertSubview(line, belowSubview: list)
            NSLayoutConstraint.activate([
                line.centerXAnchor.constraint(equalTo: icons[index].centerXAnchor),
                line.widthAnchor.constraint(equalToConstant: 2),
                line.topAnchor.constraint(equalTo: icons[index].bottomAnchor),
                line.bottomAnchor.constraint(equalTo: icons[index + 1].topAnchor)
            ])
        }
        return card
    }

    /// The trial button and the three small links, fixed under the scroll area.
    private func makeBottomBar() -> UIStackView {
        startButton.setTitle("Start 3-Day Free Trial", for: .normal)
        startButton.setTitleColor(CommonColor.white.color, for: .normal)
        startButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        startButton.backgroundColor = UIColor(hex: 0x004BF9)
        startButton.heightAnchor.constraint(equalToConstant: LottieManager.buttonHeight).isActive = true
        startButton.addTarget(self, action: #selector(onTap_start), for: .touchUpInside)

        let links = makeLegalLinks { [weak self] in self?.close() }

        let stack = UIStackView(arrangedSubviews: [startButton, links])
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

    /// Puts the store's prices on the cards once the products are loaded, and shows or hides each plan's
    /// free-trial box from the Remote Config switches (`FreeTrialPolicy`).
    @objc private func refreshPrices() {
        if let display = SubscriptionManager.shared.display(for: .monthly) {
            monthly.update(price: display.price, perDay: display.perDay, trial: display.trial)
        }
        if let display = SubscriptionManager.shared.display(for: .yearly) {
            yearly.update(price: display.price, perDay: display.perDay, trial: display.trial)
        }
        monthly.setTrial(FreeTrialPolicy.text(for: .monthly))
        yearly.setTrial(FreeTrialPolicy.text(for: .yearly))
        updateButtonTitle()
    }

    /// "3 Day Free Trial" while the selected plan shows a trial, otherwise "Continue".
    private func updateButtonTitle() {
        startButton.setTitle(FreeTrialPolicy.buttonTitle(for: selectedPlan), for: .normal)
    }

    /// Buys the selected plan; "Premium Activated!" then closes this screen.
    @objc private func onTap_start() {
        startPurchase(of: selectedPlan) { [weak self] in self?.close() }
    }

    @objc private func onTap_close() {
        close()
    }

    private func close() {
        dismiss(animated: true) { [onClose] in onClose?() }
    }
}
