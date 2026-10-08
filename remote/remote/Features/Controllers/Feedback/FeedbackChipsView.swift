import UIKit

/// The reasons as rounded chips that wrap onto new lines. Any number can be selected.
final class FeedbackChipsView: UIView {

    private static let spacing: CGFloat = 12
    private static let chipHeight: CGFloat = 40

    private(set) var selected: Set<FeedbackOption> = []
    var onChange: ((Set<FeedbackOption>) -> Void)?

    private var chips: [FeedbackOption: HapticButton] = [:]
    private var heightConstraint: NSLayoutConstraint!
    private var lastWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        heightConstraint = heightAnchor.constraint(equalToConstant: Self.chipHeight)
        heightConstraint.isActive = true
        for option in FeedbackOption.allCases {
            let chip = makeChip(option)
            chips[option] = chip
            addSubview(chip)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("FeedbackChipsView is built in code")
    }

    private func makeChip(_ option: FeedbackOption) -> HapticButton {
        let chip = HapticButton(type: .custom)
        chip.setTitle(option.rawValue, for: .normal)
        chip.setTitleColor(CommonColor.white.color, for: .normal)
        chip.titleLabel?.font = CommonFont.semibold.font(ofSize: 15)
        chip.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        chip.layer.cornerRadius = Self.chipHeight / 2
        chip.layer.borderWidth = 1.5
        chip.accessibilityTraits = .button
        chip.addAction(UIAction { [weak self] _ in self?.toggle(option) }, for: .touchUpInside)
        style(chip, selected: false)
        return chip
    }

    private func style(_ chip: UIButton, selected: Bool) {
        chip.backgroundColor = selected ? UIColor(hex: 0x0A2A6B).withAlphaComponent(0.6) : UIColor(hex: 0x131B2E)
        chip.layer.borderColor = (selected ? UIColor(hex: 0x004BF9) : UIColor.clear).cgColor
        chip.accessibilityValue = selected ? "Selected" : "Not selected"
    }

    private func toggle(_ option: FeedbackOption) {
        if selected.contains(option) { selected.remove(option) } else { selected.insert(option) }
        if let chip = chips[option] { style(chip, selected: selected.contains(option)) }
        onChange?(selected)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        var x: CGFloat = 0
        var y: CGFloat = 0
        for option in FeedbackOption.allCases {
            guard let chip = chips[option] else { continue }
            let width = ceil(chip.sizeThatFits(CGSize(width: bounds.width, height: Self.chipHeight)).width)
            if x > 0, x + width > bounds.width {
                x = 0
                y += Self.chipHeight + Self.spacing
            }
            chip.frame = CGRect(x: x, y: y, width: width, height: Self.chipHeight)
            x += width + Self.spacing
        }
        let total = y + Self.chipHeight
        if heightConstraint.constant != total {
            heightConstraint.constant = total
        }
    }
}
