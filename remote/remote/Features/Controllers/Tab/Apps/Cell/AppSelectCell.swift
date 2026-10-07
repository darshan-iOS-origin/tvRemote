import UIKit

/// One row of the "add apps" list: app image, name and a radio button.
final class AppSelectCell: UITableViewCell, ReusableCell {

    static let rowHeight: CGFloat = 66

    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let radioImageView = UIImageView()
    private let separator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        iconImageView.contentMode = .scaleAspectFit
        nameLabel.font = UIFont(name: "SFProText-Semibold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = CommonColor.white.color
        radioImageView.contentMode = .scaleAspectFit
        separator.backgroundColor = UIColor(hex: 0xFFFFFF, alpha: 0.07)   // #FFFFFF12

        [iconImageView, nameLabel, radioImageView, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: radioImageView.leadingAnchor, constant: -12),

            radioImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            radioImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            radioImageView.widthAnchor.constraint(equalToConstant: 24),
            radioImageView.heightAnchor.constraint(equalToConstant: 24),

            separator.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    func configure(with app: StreamingApp, isSelected: Bool) {
        iconImageView.image = UIImage(named: app.imageName)
        nameLabel.text = app.name
        radioImageView.image = UIImage(named: isSelected ? "selected_radio" : "unselect_radio")
    }
}
