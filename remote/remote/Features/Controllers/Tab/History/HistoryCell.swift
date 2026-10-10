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
    /// Covers the card for a TV that is behind Premium.
    private let lockOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let lockIcon = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// `isOnline` is nil while the check is still running: the dot stays grey.
    /// `isLocked` blurs the card (a TV behind Premium): its name and address can't be read.
    func configure(with tv: SavedTV, isOnline: Bool?, isLocked: Bool = false) {
        lockOverlay.isHidden = !isLocked
        lockIcon.isHidden = !isLocked
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

        lockOverlay.layer.cornerRadius = 20
        lockOverlay.clipsToBounds = true
        lockOverlay.isHidden = true
        lockIcon.image = UIImage(named: "lock") ?? UIImage(systemName: "lock.fill")
        lockIcon.tintColor = CommonColor.white.color
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.isHidden = true
        [lockOverlay, lockIcon].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        NSLayoutConstraint.activate([
            lockOverlay.topAnchor.constraint(equalTo: card.topAnchor),
            lockOverlay.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            lockOverlay.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            lockOverlay.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            lockIcon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            lockIcon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            lockIcon.widthAnchor.constraint(equalToConstant: 28),
            lockIcon.heightAnchor.constraint(equalToConstant: 28),

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
