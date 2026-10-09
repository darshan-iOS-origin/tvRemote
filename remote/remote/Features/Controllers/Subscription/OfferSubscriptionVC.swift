import UIKit

/// The special offer shown when the Subscription screen is closed: "50% OFF", the benefits as a checklist,
/// the regular and the offer price, and a "Claim 50% OFF" button. UI only for now: nothing is bought, and
/// the button and the links do nothing yet. The banner stays at the top and the button and links at the
/// bottom; the part between scrolls (only a small phone needs that).
final class OfferSubscriptionVC: UIViewController {

    private static let bannerAspect: CGFloat = 290.0 / 393.0
    /// How far the title overlaps the bottom of the banner.
    private static let titleOverlap: CGFloat = 16
    private static let yellow = UIColor(hex: 0xFFC21A)
    private static let muted = UIColor(hex: 0x707A91)
    private static let card = UIColor(hex: 0x10182C)
    private static let cardBorder = UIColor(hex: 0x202A40)

    private let closeButton = HapticButton(type: .custom)
    private let claimButton = HapticButton(type: .custom)
    private let scrollView = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        closeButton.updateGlassFallbackCorners()
    }

    // MARK: - Layout

    private func setupViews() {
        let banner = UIImageView(image: UIImage(named: "offer_top_banner"))
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
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalTo: banner.widthAnchor, multiplier: Self.bannerAspect),

            bottomBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            bottomBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            bottomBar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: -Self.titleOverlap),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            content.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -8),

            closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
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
            circle.widthAnchor.constraint(equalToConstant: 20),
            circle.heightAnchor.constraint(equalToConstant: 20),
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
        let regularPrice = UILabel()
        regularPrice.attributedText = NSAttributedString(string: "$69.99", attributes: [
            .font: CommonFont.bold.font(ofSize: 22),
            .foregroundColor: Self.muted,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ])
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
            badge.widthAnchor.constraint(equalToConstant: 64),
            badge.heightAnchor.constraint(equalToConstant: 18)
        ])
        let offerPrice = makeLabel("$39.99", font: CommonFont.bold.font(ofSize: 24), color: CommonColor.white.color)
        let offerYear = makeLabel("/Year", font: CommonFont.medium.font(ofSize: 14), color: CommonColor.white.color)
        let offer = UIStackView(arrangedSubviews: [badgeHolder, offerPrice, offerYear])
        offer.axis = .vertical
        offer.alignment = .center
        offer.spacing = 2

        let divider = UIView()
        divider.backgroundColor = Self.cardBorder
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true

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

        func link(_ title: String) -> UIButton {
            let button = HapticButton(type: .custom)
            button.setAttributedTitle(NSAttributedString(string: title, attributes: [
                .font: CommonFont.medium.font(ofSize: 11),
                .foregroundColor: Self.muted,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]), for: .normal)
            return button
        }
        let links = UIStackView(arrangedSubviews: [link("Privacy Policy"), link("Restore Purchase"), link("Terms of Service")])
        links.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [claimButton, links])
        stack.axis = .vertical
        stack.spacing = 14
        return stack
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
        dismiss(animated: true)
    }
}
