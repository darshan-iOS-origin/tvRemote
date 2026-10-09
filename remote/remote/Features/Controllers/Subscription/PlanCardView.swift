import UIKit

/// One subscription plan: its name, price, price per day and a free-trial chip. The selected card has a
/// blue border and a soft blue fill (a top-to-bottom gradient of #004BF9 at 10% into 30%); the other one
/// is dark. A plan can carry a yellow ribbon in its top right corner ("SAVE 90%").
final class PlanCardView: UIControl {

    private static let blue = UIColor(hex: 0x004BF9)
    private static let muted = UIColor(hex: 0x707A91)

    private let fillLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let perDayLabel = UILabel()
    private let trialChip = UILabel()
    private let ribbon = UILabel()

    init(title: String, price: String, perDay: String, trial: String, ribbon ribbonText: String? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 20
        layer.borderWidth = 1.5
        clipsToBounds = true

        fillLayer.colors = [Self.blue.withAlphaComponent(0.1).cgColor, Self.blue.withAlphaComponent(0.3).cgColor]
        fillLayer.startPoint = CGPoint(x: 0.5, y: 0)
        fillLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(fillLayer, at: 0)

        titleLabel.text = title
        titleLabel.font = CommonFont.medium.font(ofSize: 15)
        priceLabel.text = price
        priceLabel.font = CommonFont.bold.font(ofSize: 28)
        priceLabel.textColor = CommonColor.white.color
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.7
        perDayLabel.text = perDay
        perDayLabel.font = CommonFont.medium.font(ofSize: 12)
        perDayLabel.textColor = Self.muted

        trialChip.text = trial
        trialChip.font = CommonFont.medium.font(ofSize: 10)
        trialChip.textAlignment = .center
        trialChip.layer.cornerRadius = 9
        trialChip.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, priceLabel, perDayLabel, trialChip])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.setCustomSpacing(8, after: perDayLabel)
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        trialChip.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 124),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 4),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            trialChip.heightAnchor.constraint(equalToConstant: 18),
            trialChip.widthAnchor.constraint(equalToConstant: 84)
        ])

        if let ribbonText {
            ribbon.text = ribbonText
            ribbon.font = CommonFont.bold.font(ofSize: 10)
            ribbon.textColor = .black
            ribbon.textAlignment = .center
            ribbon.backgroundColor = UIColor(hex: 0xFFC21A)
            ribbon.layer.cornerRadius = 8
            ribbon.layer.maskedCorners = [.layerMinXMaxYCorner]
            ribbon.clipsToBounds = true
            ribbon.isUserInteractionEnabled = false
            ribbon.translatesAutoresizingMaskIntoConstraints = false
            addSubview(ribbon)
            NSLayoutConstraint.activate([
                ribbon.topAnchor.constraint(equalTo: topAnchor),
                ribbon.trailingAnchor.constraint(equalTo: trailingAnchor),
                ribbon.heightAnchor.constraint(equalToConstant: 20),
                ribbon.widthAnchor.constraint(equalToConstant: 68)
            ])
        }

        isAccessibilityElement = true
        accessibilityLabel = "\(title), \(price), \(perDay)"
        accessibilityTraits = .button
        setSelectedStyle(false)
    }

    required init?(coder: NSCoder) {
        fatalError("PlanCardView is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillLayer.frame = bounds
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
