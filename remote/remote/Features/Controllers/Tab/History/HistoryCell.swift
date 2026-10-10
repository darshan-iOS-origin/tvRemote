import UIKit

/// One TV in the history list: icon, name, address and a green / red online dot.
final class HistoryCell: UITableViewCell, ReusableCell {

    private let card = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let defaultLabel = UILabel()
    private let defaultBadge = UIView()
    private let addressLabel = UILabel()
    private let dot = UIView()
    /// Covers the card of a TV that is behind Premium, with a lock and text on top (sharp).
    private let lockBlur = UIVisualEffectView(effect: nil)
    private let lockBadge = UIStackView()
    private var blurAnimator: UIViewPropertyAnimator?
    /// 0 is no blur, 1 is the full `.dark` blur.
    private static let blurAmount: CGFloat = 0.12

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// `isOnline` is nil while the check is still running: the dot stays grey.
    /// `isLocked` blurs the card (a TV behind Premium) and shows a lock with text on it.
    func configure(with tv: SavedTV, isOnline: Bool?, isLocked: Bool = false) {
        lockBlur.isHidden = !isLocked
        lockBadge.isHidden = !isLocked
        // iOS resets a paused animation (app in the background, cell reuse): set the strength again.
        blurAnimator?.fractionComplete = Self.blurAmount
        isAccessibilityElement = isLocked
        accessibilityLabel = isLocked ? "Locked. Premium required." : nil
        nameLabel.text = tv.device.name
        addressLabel.text = tv.host
        defaultBadge.isHidden = tv.isDefault != true
        switch isOnline {
        case .some(true): dot.backgroundColor = UIColor(hex: 0x1FB84A)
        case .some(false): dot.backgroundColor = UIColor(hex: 0xE5252A)
        case .none: dot.backgroundColor = UIColor(hex: 0x707A91)
        }
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.backgroundColor = UIColor(hex: 0x10182C)
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1.5
        card.layer.borderColor = UIColor(hex: 0x202A40).cgColor

        // ic_tv already includes the round blue background.
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(named: "ic_tv")

        nameLabel.font = CommonFont.semibold.font(ofSize: 14)
        nameLabel.textColor = CommonColor.white.color
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.numberOfLines = 1
        nameLabel.setContentHuggingPriority(.init(251), for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        defaultLabel.text = "Default"
        defaultLabel.font = CommonFont.semibold.font(ofSize: 10)
        defaultLabel.textColor = CommonColor.white.color
        defaultLabel.translatesAutoresizingMaskIntoConstraints = false
        defaultBadge.backgroundColor = UIColor(hex: 0x004BF9)
        defaultBadge.layer.cornerRadius = 9
        defaultBadge.addSubview(defaultLabel)
        NSLayoutConstraint.activate([
            defaultLabel.topAnchor.constraint(equalTo: defaultBadge.topAnchor, constant: 3),
            defaultLabel.bottomAnchor.constraint(equalTo: defaultBadge.bottomAnchor, constant: -3),
            defaultLabel.leadingAnchor.constraint(equalTo: defaultBadge.leadingAnchor, constant: 8),
            defaultLabel.trailingAnchor.constraint(equalTo: defaultBadge.trailingAnchor, constant: -8)
        ])
        defaultBadge.setContentHuggingPriority(.required, for: .horizontal)
        defaultBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        addressLabel.font = CommonFont.medium.font(ofSize: 12)
        addressLabel.textColor = UIColor(hex: 0x707A91)

        dot.layer.cornerRadius = 4
        dot.isAccessibilityElement = false

        // Soaks up the free width so the badge stays right after the name.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        let nameRow = UIStackView(arrangedSubviews: [nameLabel, defaultBadge, spacer])
        nameRow.alignment = .center
        nameRow.spacing = 6
        let texts = UIStackView(arrangedSubviews: [nameRow, addressLabel])
        texts.axis = .vertical
        texts.spacing = 4

        [card, iconView, texts, dot].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        contentView.addSubview(card)
        [iconView, texts, dot].forEach { card.addSubview($0) }

        // A blur effect has no strength setting: a paused animation to the full effect, held part of the
        // way, gives a lighter one.
        lockBlur.layer.cornerRadius = 20
        lockBlur.clipsToBounds = true
        lockBlur.isHidden = true
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in
            self?.lockBlur.effect = UIBlurEffect(style: .dark)
        }
        animator.pausesOnCompletion = true
        animator.fractionComplete = Self.blurAmount
        blurAnimator = animator

        let lockIcon = UIImageView(image: UIImage(named: "lock") ?? UIImage(systemName: "lock.fill"))
        lockIcon.tintColor = CommonColor.white.color
        lockIcon.contentMode = .scaleAspectFit
        let lockText = UILabel()
        lockText.text = "Unlock with Premium"
        lockText.font = CommonFont.semibold.font(ofSize: 14)
        lockText.textColor = CommonColor.white.color
        [lockIcon, lockText].forEach { lockBadge.addArrangedSubview($0) }
        lockBadge.alignment = .center
        lockBadge.spacing = 8
        lockBadge.isHidden = true
        [lockBlur, lockBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        NSLayoutConstraint.activate([
            lockBlur.topAnchor.constraint(equalTo: card.topAnchor),
            lockBlur.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            lockBlur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            lockBlur.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            lockIcon.widthAnchor.constraint(equalToConstant: 24),
            lockIcon.heightAnchor.constraint(equalToConstant: 24),
            lockBadge.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            lockBadge.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.heightAnchor.constraint(equalToConstant: 76),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            texts.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            texts.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            texts.trailingAnchor.constraint(equalTo: dot.leadingAnchor, constant: -12),

            dot.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            dot.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
}
