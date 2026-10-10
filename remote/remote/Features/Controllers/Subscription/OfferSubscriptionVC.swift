import UIKit

/// The special offer shown when the Subscription screen is closed: "50% OFF", the benefits as a checklist,
/// the regular and the offer price, and a "Claim 50% OFF" button that buys the yearly offer plan. The banner
/// stays at the top and the button and links at the bottom; the part between scrolls (only a small phone
/// needs that). The prices come from the store; the regular price is twice the offer price (the "50% OFF").
final class OfferSubscriptionVC: UIViewController {

    /// Runs once this screen has closed (by the X, or after "Premium Activated!"). Set by `IAPFlowManager`.
    var onClose: (() -> Void)?

    private static let bannerAspect: CGFloat = 290.0 / 393.0
    /// The Subscription screen's banner proportions (393×250).
    private static let subscriptionBannerAspect: CGFloat = 250.0 / 393.0
    /// The title always overlaps the bottom of the banner by at least this much...
    private static let minTitleOverlap: CGFloat = 16
    /// ...and by at most this much, when the screen is short and needs the room.
    private static let maxTitleOverlap: CGFloat = 150
    private static let yellow = UIColor(hex: 0xFDD200)
    private static let muted = UIColor(hex: 0x707A91)
    private static let card = UIColor(hex: 0x10182C)
    private static let cardBorder = UIColor(hex: 0x202A40)

    private let closeButton = HapticButton(type: .custom)
    private let claimButton = HapticButton(type: .custom)
    private let scrollView = UIScrollView()
    private let regularPriceLabel = UILabel()
    private let offerPriceLabel = UILabel()
    private var contentStack: UIStackView?
    private var bannerView: UIImageView?
    /// The empty space at the top of the scroll content, as tall as the banner less the title overlap.
    private var bannerSpaceHeight: NSLayoutConstraint?
    /// Top of the background glow, measured up from the bottom of the banner (see `glowTop`).
    private var glowTop: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GradientBackgroundView.baseColor
        setupViews()
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
        // The glow starts as far above the banner's bottom edge as the Subscription banner is tall, so below
        // the banner it looks the same as on the Subscription screen (this banner is taller, and would
        // otherwise hide more of the glow).
        glowTop?.constant = -(view.bounds.width * Self.subscriptionBannerAspect)
        fitContentToScreen()
    }

    /// Moves the title up over the banner just enough for everything to fit without scrolling. Only when
    /// even the largest overlap is not enough (a small phone, or large text) does the screen scroll.
    private func fitContentToScreen() {
        guard let contentStack, let bannerView, let bannerSpaceHeight, scrollView.bounds.height > 0 else { return }
        let contentHeight = contentStack.systemLayoutSizeFitting(
            CGSize(width: view.bounds.width - 32, height: UIView.layoutFittingCompressedSize.height),
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
        let banner = UIImageView(image: UIImage(named: "offer_top_banner"))
        banner.contentMode = .scaleAspectFill
        banner.clipsToBounds = true
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)

        // The same background glow as on the other screens, behind everything.
        let glow = GradientBackgroundView()
        glow.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(glow, at: 0)
        let glowTopConstraint = glow.topAnchor.constraint(equalTo: banner.bottomAnchor)
        glowTop = glowTopConstraint
        NSLayoutConstraint.activate([
            glowTopConstraint,
            glow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glow.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

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
        // An empty header as tall as the banner (less the overlap): the content starts below the banner, and
        // when it scrolls it moves up over the banner.
        let bannerSpace = UIView()
        bannerSpace.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(bannerSpace)
        scrollView.addSubview(content)
        let spaceHeight = bannerSpace.heightAnchor.constraint(equalToConstant: DeviceLayout.s(200))
        bannerSpaceHeight = spaceHeight

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
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalTo: banner.widthAnchor, multiplier: Self.bannerAspect),

            bottomBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            bottomBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
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
            content.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -8),

            closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: DeviceLayout.s(40)),
            closeButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(40))
        ])
        LottieManager.applyButtonBackground(to: claimButton)
    }

    /// The three title lines, the checklist card and the price card.
    private func makeContent() -> UIStackView {
        let special = UILabel()
        special.text = "Get a Special Offer"
        special.font = CommonFont.medium.font(ofSize: 22)
        special.textColor = CommonColor.white.color
        special.textAlignment = .center

        let off = UILabel()
        off.text = "50% OFF"
        off.font = CommonFont.black.font(ofSize: 50)
        off.textColor = Self.yellow
        off.textAlignment = .center
        off.adjustsFontSizeToFitWidth = true
        off.minimumScaleFactor = 0.6

        let tagline = UILabel()
        tagline.text = "A Change the way you feel"
        tagline.font = CommonFont.regular.font(ofSize: 18)
        tagline.textColor = Self.muted
        tagline.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [special, off, tagline, makeChecklistCard(), makePriceCard()])
        stack.axis = .vertical
        stack.spacing = 0
        stack.setCustomSpacing(2, after: special)
        stack.setCustomSpacing(6, after: off)
        stack.setCustomSpacing(24, after: tagline)
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[3])
        return stack
    }

    private func makeChecklistCard() -> UIView {
        let rows = UIStackView(arrangedSubviews: [
            makeCheckRow("Instant TV Connection"),
            makeCheckRow("Cast All Media to TV"),
            makeCheckRow("Access All Premium Features"),
            makeCheckRow("Ad-Free Experience")
        ])
        rows.axis = .vertical
        rows.spacing = 16
        return wrapInCard(rows, insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
    }

    /// A blue circle with a white check mark, and the benefit beside it.
    private func makeCheckRow(_ text: String) -> UIView {
        let circle = UIView()
        circle.backgroundColor = UIColor(hex: 0x004BF9)
        circle.layer.cornerRadius = 10
        let check = UIImageView(image: IconsHelper.image(systemName: "checkmark", pointSize: 10))
        check.tintColor = CommonColor.white.color
        check.contentMode = .center
        check.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(check)
        circle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: DeviceLayout.s(20)),
            circle.heightAnchor.constraint(equalToConstant: DeviceLayout.s(20)),
            check.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])
        let label = UILabel()
        label.text = text
        label.font = CommonFont.medium.font(ofSize: 14)
        label.textColor = CommonColor.white.color
        label.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [circle, label])
        row.alignment = .center
        row.spacing = 14
        return row
    }

    /// "Regular Price / $69.99 crossed out / /Year", a divider, and the "50% OFF" badge over "$39.99 /Year".
    private func makePriceCard() -> UIView {
        let regularTitle = makeLabel("Regular Price", font: CommonFont.medium.font(ofSize: 14), color: Self.muted)
        let regularPrice = regularPriceLabel
        regularPrice.attributedText = Self.regularPriceText("$69.99")
        let regularYear = makeLabel("/Year", font: CommonFont.medium.font(ofSize: 14), color: Self.muted)
        let regular = UIStackView(arrangedSubviews: [regularTitle, regularPrice, regularYear])
        regular.axis = .vertical
        regular.alignment = .center
        regular.spacing = 2

        let badge = UILabel()
        badge.text = "50% OFF"
        badge.font = CommonFont.bold.font(ofSize: 10)
        badge.textColor = .black
        badge.textAlignment = .center
        badge.backgroundColor = Self.yellow
        badge.layer.cornerRadius = 9
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        let badgeHolder = UIStackView(arrangedSubviews: [badge])
        badgeHolder.alignment = .center
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: DeviceLayout.s(64)),
            badge.heightAnchor.constraint(equalToConstant: DeviceLayout.s(18))
        ])
        let offerPrice = offerPriceLabel
        offerPrice.text = "$39.99"
        offerPrice.font = CommonFont.bold.font(ofSize: 24)
        offerPrice.textColor = CommonColor.white.color
        offerPrice.textAlignment = .center
        let offerYear = makeLabel("/Year", font: CommonFont.medium.font(ofSize: 14), color: CommonColor.white.color)
        let offer = UIStackView(arrangedSubviews: [badgeHolder, offerPrice, offerYear])
        offer.axis = .vertical
        offer.alignment = .center
        offer.spacing = 2

        let divider = UIView()
        divider.backgroundColor = Self.cardBorder
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: DeviceLayout.s(1)).isActive = true

        let row = UIStackView(arrangedSubviews: [regular, divider, offer])
        row.alignment = .fill
        row.spacing = 16
        regular.widthAnchor.constraint(equalTo: offer.widthAnchor).isActive = true
        return wrapInCard(row, insets: UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16))
    }

    /// "Claim 50% OFF" with the animated button background, and the three small links.
    private func makeBottomBar() -> UIStackView {
        claimButton.setTitle("Claim 50% OFF", for: .normal)
        claimButton.setTitleColor(CommonColor.white.color, for: .normal)
        claimButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        claimButton.backgroundColor = UIColor(hex: 0x004BF9)
        claimButton.heightAnchor.constraint(equalToConstant: LottieManager.buttonHeight).isActive = true
        claimButton.addTarget(self, action: #selector(onTap_claim), for: .touchUpInside)

        let links = makeLegalLinks { [weak self] in self?.close() }

        let stack = UIStackView(arrangedSubviews: [claimButton, links])
        stack.axis = .vertical
        stack.spacing = 14
        return stack
    }

    // MARK: - Prices and buying

    private static func regularPriceText(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: CommonFont.bold.font(ofSize: 22),
            .foregroundColor: muted,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ])
    }

    /// Puts the store's offer price, and twice that as the crossed-out regular price, on the card.
    @objc private func refreshPrices() {
        guard let offer = SubscriptionManager.shared.display(for: .yearlyOffer) else { return }
        offerPriceLabel.text = offer.price
        if let regular = SubscriptionManager.shared.doubledPriceString(for: .yearlyOffer) {
            regularPriceLabel.attributedText = Self.regularPriceText(regular)
        }
    }

    /// Buys the yearly offer plan; "Premium Activated!" then closes this screen.
    @objc private func onTap_claim() {
        startPurchase(of: .yearlyOffer) { [weak self] in self?.close() }
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = .center
        return label
    }

    private func wrapInCard(_ content: UIView, insets: UIEdgeInsets) -> UIView {
        let card = UIView()
        card.backgroundColor = Self.card
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = Self.cardBorder.cgColor
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: insets.top),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -insets.bottom),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: insets.left),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -insets.right)
        ])
        return card
    }

    @objc private func onTap_close() {
        close()
    }

    private func close() {
        dismiss(animated: true) { [onClose] in onClose?() }
    }
}
