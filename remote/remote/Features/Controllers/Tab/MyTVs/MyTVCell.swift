import UIKit

/// One saved TV on the My TVs screen: icon, name, address, a heart, a status pill and a connect /
/// disconnect button. The heart adds the TV to the Favourites tab.
final class MyTVCell: UITableViewCell, ReusableCell {

    private let card = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let heartButton = HapticButton(type: .custom)
    private let statusPill = UIView()
    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let actionButton = HapticButton(type: .custom)

    private var onToggleConnection: (() -> Void)?
    /// Gets the new heart state; returns false to refuse it (the heart then goes back).
    private var onToggleFavorite: ((Bool) -> Bool)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with tv: SavedTV, isConnected: Bool,
                   onToggleConnection: @escaping () -> Void,
                   onToggleFavorite: @escaping (Bool) -> Bool) {
        self.onToggleConnection = onToggleConnection
        self.onToggleFavorite = onToggleFavorite
        setHeart(selected: tv.isFavorite == true)
        nameLabel.text = tv.device.name
        addressLabel.text = tv.host
        if isConnected {
            statusLabel.text = "Connected"
            statusLabel.textColor = UIColor(hex: 0x3FD96B)
            statusDot.backgroundColor = UIColor(hex: 0x1FB84A)
            statusPill.backgroundColor = UIColor(hex: 0x0E3A27)
            actionButton.setTitle("Disconnect", for: .normal)
            actionButton.backgroundColor = UIColor(hex: 0xE5252A)
        } else {
            statusLabel.text = "Not Connected"
            statusLabel.textColor = UIColor(hex: 0xA3ADC2)
            statusDot.backgroundColor = UIColor(hex: 0x707A91)
            statusPill.backgroundColor = UIColor(hex: 0x202A40)
            actionButton.setTitle("Connect", for: .normal)
            actionButton.backgroundColor = UIColor(hex: 0x004BF9)
        }
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.backgroundColor = UIColor(hex: 0x10182C)
        card.layer.cornerRadius = DeviceLayout.s(20)
        card.layer.borderWidth = 1.5
        card.layer.borderColor = UIColor(hex: 0x202A40).cgColor

        // ic_tv already includes the round blue background.
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(named: "ic_tv")

        nameLabel.font = CommonFont.semibold.font(ofSize: 14)
        nameLabel.textColor = CommonColor.white.color
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail

        addressLabel.font = CommonFont.medium.font(ofSize: 12)
        addressLabel.textColor = UIColor(hex: 0x707A91)

        heartButton.setImage(IconsHelper.image(systemName: "heart", pointSize: 16), for: .normal)
        heartButton.setImage(IconsHelper.image(systemName: "heart.fill", pointSize: 16), for: .selected)
        heartButton.tintColor = UIColor(hex: 0x707A91)
        heartButton.accessibilityLabel = "Favorite"
        heartButton.addTarget(self, action: #selector(onTap_heart), for: .touchUpInside)

        statusDot.layer.cornerRadius = DeviceLayout.s(3)
        statusLabel.font = CommonFont.medium.font(ofSize: 11)
        statusPill.layer.cornerRadius = DeviceLayout.s(16)
        let statusRow = UIStackView(arrangedSubviews: [statusDot, statusLabel])
        statusRow.spacing = 6
        statusRow.alignment = .center
        statusRow.isUserInteractionEnabled = false
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusRow)

        actionButton.titleLabel?.font = CommonFont.semibold.font(ofSize: 12)
        actionButton.setTitleColor(CommonColor.white.color, for: .normal)
        actionButton.layer.cornerRadius = DeviceLayout.s(16)
        actionButton.addTarget(self, action: #selector(onTap_action), for: .touchUpInside)

        let texts = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        texts.axis = .vertical
        texts.spacing = 4

        let pills = UIStackView(arrangedSubviews: [statusPill, actionButton])
        pills.spacing = 8
        pills.distribution = .fillEqually

        [card, iconView, texts, heartButton, pills, statusDot].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        contentView.addSubview(card)
        [iconView, texts, heartButton, pills].forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DeviceLayout.s(6)),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DeviceLayout.s(6)),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DeviceLayout.s(16)),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DeviceLayout.s(16)),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DeviceLayout.s(12)),
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: DeviceLayout.s(14)),
            iconView.widthAnchor.constraint(equalToConstant: DeviceLayout.s(44)),
            iconView.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44)),

            texts.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DeviceLayout.s(12)),
            texts.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            texts.trailingAnchor.constraint(equalTo: heartButton.leadingAnchor, constant: -DeviceLayout.s(8)),

            heartButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DeviceLayout.s(12)),
            heartButton.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            heartButton.widthAnchor.constraint(equalToConstant: DeviceLayout.s(32)),
            heartButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(32)),

            pills.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DeviceLayout.s(12)),
            pills.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DeviceLayout.s(12)),
            pills.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: DeviceLayout.s(70)),
            pills.widthAnchor.constraint(equalToConstant: DeviceLayout.s(232)),
            pills.heightAnchor.constraint(equalToConstant: DeviceLayout.s(32)),
            pills.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DeviceLayout.s(14)),

            statusRow.centerXAnchor.constraint(equalTo: statusPill.centerXAnchor),
            statusRow.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: DeviceLayout.s(6)),
            statusDot.heightAnchor.constraint(equalToConstant: DeviceLayout.s(6))
        ])
    }

    private func setHeart(selected: Bool) {
        heartButton.isSelected = selected
        heartButton.tintColor = selected ? UIColor(hex: 0xE5252A) : UIColor(hex: 0x707A91)
    }

    @objc private func onTap_heart() {
        let wanted = !heartButton.isSelected
        setHeart(selected: wanted)
        if onToggleFavorite?(wanted) == false {
            setHeart(selected: !wanted)
        }
    }

    @objc private func onTap_action() {
        onToggleConnection?()
    }
}
