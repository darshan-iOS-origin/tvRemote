import UIKit

/// One subscription plan: its name, price, price per day and a free-trial chip. The selected card has a
/// blue border and a soft blue fill (a top-to-bottom gradient of #004BF9 at 10% into 30%); the other one
/// is dark. A plan can carry a yellow ribbon in its top right corner ("SAVE 90%").
final class PlanCardView: UIControl {

    private static let blue = UIColor(hex: 0x004BF9)
    private static let muted = UIColor(hex: 0x707A91)
    /// The gap between the title, the price, the price per day and the trial chip.
    /// 1 on iPhone; `DeviceLayout.padPlanCardScale` on iPad. Every size below is multiplied by it.
    private static let k: CGFloat = DeviceLayout.isPad ? DeviceLayout.padPlanCardScale : 1
    private static let labelSpacing: CGFloat = 6 * k
    /// With the trial tab showing, the three labels are centred in the 122 pt above it, which leaves about 21 pt
    /// above the top one: clear of the 20 pt "SAVE 90%" ribbon.
    private static let cardHeight: CGFloat = 144 * k
    /// The free-trial tab: it grows out of the bottom edge, 22 pt tall and a bit over half the card wide.
    private static let trialTabHeight: CGFloat = 22 * k
    private static let trialTabWidthShare: CGFloat = 0.58

    private let fillLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let perDayLabel = UILabel()
    private let trialChip = UILabel()
    private let ribbon = RibbonLabel()
    /// The labels' vertical centre: the middle of the box, or of the part above the trial tab when it shows.
    private var stackCenterY: NSLayoutConstraint?

    init(title: String, price: String, perDay: String, trial: String, ribbon ribbonText: String? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 20 * Self.k
        layer.borderWidth = 1.5
        clipsToBounds = true

        fillLayer.colors = [Self.blue.withAlphaComponent(0.1).cgColor, Self.blue.withAlphaComponent(0.3).cgColor]
        fillLayer.startPoint = CGPoint(x: 0.5, y: 0)
        fillLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(fillLayer, at: 0)

        titleLabel.text = title
        titleLabel.font = CommonFont.semibold.font(ofSize: 16 * Self.k)
        priceLabel.text = price
        priceLabel.font = CommonFont.heavy.font(ofSize: 28 * Self.k)
        priceLabel.textColor = CommonColor.white.color
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.7
        perDayLabel.text = perDay
        perDayLabel.font = CommonFont.semibold.font(ofSize: 12 * Self.k)
        perDayLabel.textColor = Self.muted

        trialChip.text = trial
        trialChip.font = CommonFont.medium.font(ofSize: 10 * Self.k)
        trialChip.adjustsFontSizeToFitWidth = true
        trialChip.minimumScaleFactor = 0.7
        trialChip.textAlignment = .center
        // A tab on the bottom edge: only its top corners are round.
        trialChip.layer.cornerRadius = 12 * Self.k
        trialChip.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        trialChip.clipsToBounds = true

        // Only these three labels are centred in the box; the trial tab is separate.
        let stack = UIStackView(arrangedSubviews: [titleLabel, priceLabel, perDayLabel])
        stack.axis = .vertical
        stack.alignment = .center
        // The same gap between every label.
        stack.spacing = Self.labelSpacing
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        trialChip.isUserInteractionEnabled = false
        trialChip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trialChip)

        let centerY = stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        stackCenterY = centerY
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.cardHeight),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerY,
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            trialChip.centerXAnchor.constraint(equalTo: centerXAnchor),
            trialChip.bottomAnchor.constraint(equalTo: bottomAnchor),
            trialChip.heightAnchor.constraint(equalToConstant: Self.trialTabHeight),
            trialChip.widthAnchor.constraint(equalTo: widthAnchor, multiplier: Self.trialTabWidthShare)
        ])

        if let ribbonText {
            ribbon.text = ribbonText
            ribbon.font = CommonFont.bold.font(ofSize: 10 * Self.k)
            ribbon.textColor = .black
            ribbon.textAlignment = .center
            ribbon.backgroundColor = UIColor(hex: 0xFDD200)
            ribbon.layer.cornerRadius = 8 * Self.k
            ribbon.layer.maskedCorners = [.layerMinXMaxYCorner]
            ribbon.clipsToBounds = true
            ribbon.isUserInteractionEnabled = false
            ribbon.translatesAutoresizingMaskIntoConstraints = false
            addSubview(ribbon)
            NSLayoutConstraint.activate([
                ribbon.topAnchor.constraint(equalTo: topAnchor),
                ribbon.trailingAnchor.constraint(equalTo: trailingAnchor),
                // 20 x 68 pt on iPhone. A little taller on iPad, and never narrower than its text plus padding, so the
                // bigger iPad font is not cut.
                ribbon.heightAnchor.constraint(equalToConstant: 20 * DeviceLayout.padFontScale * Self.k),
                ribbon.widthAnchor.constraint(greaterThanOrEqualToConstant: 68 * Self.k)
            ])
        }

        isAccessibilityElement = true
        accessibilityLabel = "\(title), \(price), \(perDay)"
        accessibilityTraits = .button
        setSelectedStyle(false)
        updateCentering()
    }

    required init?(coder: NSCoder) {
        fatalError("PlanCardView is built in code")
    }

    /// The Monthly and Yearly cards side by side, sharing the width. On iPad the pair is at most
    /// `DeviceLayout.padPlansMaxWidth` wide and centred, so the cards are not stretched across the whole screen.
    static func makePlansRow(_ monthly: PlanCardView, _ yearly: PlanCardView) -> UIView {
        let plans = UIStackView(arrangedSubviews: [monthly, yearly])
        plans.spacing = 16
        plans.distribution = .fillEqually
        guard DeviceLayout.isPad else { return plans }

        let container = UIView()
        plans.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(plans)
        let fill = plans.widthAnchor.constraint(equalTo: container.widthAnchor)
        fill.priority = .defaultHigh
        NSLayoutConstraint.activate([
            plans.topAnchor.constraint(equalTo: container.topAnchor),
            plans.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            plans.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            plans.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            plans.widthAnchor.constraint(lessThanOrEqualToConstant: DeviceLayout.padPlansMaxWidth),
            fill
        ])
        return container
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillLayer.frame = bounds
    }

    /// Shows the store's real price, price per day and free-trial text. A nil `trial` hides the chip (the
    /// plan has no trial, or the user already used it).
    func update(price: String, perDay: String, trial: String?) {
        priceLabel.text = price
        perDayLabel.text = perDay
        trialChip.text = trial
        trialChip.isHidden = trial == nil
        updateCentering()
        accessibilityLabel = "\(titleLabel.text ?? ""), \(price), \(perDay)"
    }

    /// Shows the free-trial box with `text`, or hides it for nil.
    func setTrial(_ text: String?) {
        trialChip.text = text
        trialChip.isHidden = text == nil
        updateCentering()
    }

    /// Centres the three labels in the part of the box that is left: all of it, or what is above the trial tab.
    private func updateCentering() {
        stackCenterY?.constant = trialChip.isHidden ? 0 : -Self.trialTabHeight / 2
    }

    /// Selected: blue border and fill. Not selected: dark card.
    func setSelectedStyle(_ isSelected: Bool) {
        fillLayer.isHidden = !isSelected
        backgroundColor = isSelected ? .clear : UIColor(hex: 0x10182C)
        layer.borderColor = (isSelected ? Self.blue : UIColor(hex: 0x202A40)).cgColor
        titleLabel.textColor = isSelected ? CommonColor.white.color : Self.muted
        trialChip.backgroundColor = isSelected ? Self.blue : UIColor(hex: 0x202A40)
        trialChip.textColor = isSelected ? CommonColor.white.color : Self.muted
        accessibilityValue = isSelected ? "Selected" : "Not selected"
    }
}

/// The yellow "SAVE 90%" label: its text keeps 8 pt of room at both sides, so it is never touching the edge.
private final class RibbonLabel: UILabel {

    private let horizontalPadding: CGFloat = 8

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: horizontalPadding, dy: 0))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + horizontalPadding * 2, height: size.height)
    }
}
