import UIKit

final class OnboardingPageCell: UICollectionViewCell {

    static let reuseIdentifier = "OnboardingPageCell"

    /// Space reserved below the description for the pager dots and Continue button.
    private let bottomInset: CGFloat = DeviceLayout.isPad ? 150 : 130

    private let bgImageView = UIImageView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentView.backgroundColor = .clear

        // The picture fills the whole screen (extra is cropped); iPad has its own 3:4 pictures.
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.clipsToBounds = true

        titleLabel.font = CommonFont.bold.font(ofSize: 28)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .center

        descriptionLabel.font = CommonFont.regular.font(ofSize: 15)
        descriptionLabel.textColor = CommonColor.secondaryGray.color
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0

        [bgImageView, iconImageView, titleLabel, descriptionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        let safe = contentView.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),

            descriptionLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -bottomInset),

            titleLabel.centerXAnchor.constraint(equalTo: descriptionLabel.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: descriptionLabel.topAnchor, constant: -14),

            iconImageView.centerXAnchor.constraint(equalTo: titleLabel.centerXAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -20),
            iconImageView.widthAnchor.constraint(equalToConstant: DeviceLayout.isPad ? 64 : 50),
            iconImageView.heightAnchor.constraint(equalToConstant: DeviceLayout.isPad ? 64 : 50)
        ])
    }

    func configure(with page: OnboardingPage) {
        bgImageView.image = UIImage(named: page.backgroundName)
        iconImageView.image = UIImage(named: page.icon)
        titleLabel.text = page.title
        descriptionLabel.text = page.description
    }
}
