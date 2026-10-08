import UIKit

/// A favourite TV: icon, name, address and a red heart that takes it off the list. A thin line under it
/// separates it from the next one.
final class FavouriteCell: UITableViewCell, ReusableCell {

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let heartButton = HapticButton(type: .custom)
    private let separator = UIView()

    private var onUnfavorite: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with tv: SavedTV, onUnfavorite: @escaping () -> Void) {
        nameLabel.text = tv.device.name
        addressLabel.text = tv.host
        self.onUnfavorite = onUnfavorite
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(named: "ic_tv")

        nameLabel.font = CommonFont.semibold.font(ofSize: 14)
        nameLabel.textColor = CommonColor.white.color
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail

        addressLabel.font = CommonFont.medium.font(ofSize: 12)
        addressLabel.textColor = UIColor(hex: 0x707A91)

        heartButton.setImage(IconsHelper.image(systemName: "heart.fill", pointSize: 16), for: .normal)
        heartButton.tintColor = UIColor(hex: 0xE5252A)
        heartButton.accessibilityLabel = "Remove from favourites"
        heartButton.addTarget(self, action: #selector(onTap_heart), for: .touchUpInside)

        separator.backgroundColor = UIColor(hex: 0x202A40)

        let texts = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        texts.axis = .vertical
        texts.spacing = 4

        [iconView, texts, heartButton, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),
            contentView.heightAnchor.constraint(equalToConstant: 76),

            texts.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            texts.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            texts.trailingAnchor.constraint(equalTo: heartButton.leadingAnchor, constant: -8),

            heartButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            heartButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            heartButton.widthAnchor.constraint(equalToConstant: 32),
            heartButton.heightAnchor.constraint(equalToConstant: 32),

            separator.leadingAnchor.constraint(equalTo: texts.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    @objc private func onTap_heart() {
        onUnfavorite?()
    }
}
