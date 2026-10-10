import UIKit

/// One tile of the My Apps grid: an 80x80 icon with the app name below it.
/// The last tile of the grid is the "Add more" tile.
final class MyAppCell: UICollectionViewCell, ReusableCollectionCell {

    static let iconSize: CGFloat = 80
    static let labelHeight: CGFloat = 18
    static let spacing: CGFloat = 10
    static var itemHeight: CGFloat { iconSize + spacing + labelHeight }

    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        iconImageView.contentMode = .scaleAspectFit
        nameLabel.font = CommonFont.bold.font(ofSize: 15)
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.8

        [iconImageView, nameLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: Self.iconSize),

            nameLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: Self.spacing),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            nameLabel.heightAnchor.constraint(equalToConstant: Self.labelHeight)
        ])
    }

    func configure(with app: StreamingApp) {
        iconImageView.image = UIImage(named: app.imageName)
        nameLabel.text = app.name
        nameLabel.textColor = CommonColor.white.color
    }

    func configureAddMore() {
        iconImageView.image = UIImage(named: "add_more")
        nameLabel.text = "Add more"
        nameLabel.textColor = CommonColor.secondaryGray.color
    }
}
