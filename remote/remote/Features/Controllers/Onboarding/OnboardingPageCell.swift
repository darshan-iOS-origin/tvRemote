import UIKit

final class OnboardingPageCell: UICollectionViewCell {

    static let reuseIdentifier = "OnboardingPageCell"

    /// Space reserved below the description for the pager dots and Continue button.
    private let bottomInset: CGFloat = DeviceLayout.isPad ? 150 : 130
    /// iPad: fades the left and right edges of the picture, so it does not show as a hard-edged strip.
    private let edgeFade = CAGradientLayer()

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

        bgImageView.contentMode = .scaleAspectFit
        bgImageView.clipsToBounds = true
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.clipsToBounds = true

        let boost = DeviceLayout.isPad ? DeviceLayout.padTextBoost : 0
        titleLabel.font = UIFont(name: "SFProText-Bold", size: 28 + boost) ?? .boldSystemFont(ofSize: 28 + boost)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .center

        descriptionLabel.font = UIFont(name: "SFProText-Regular", size: 15 + boost) ?? .systemFont(ofSize: 15 + boost)
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

        if DeviceLayout.isPad {
            let fade = DeviceLayout.padImageEdgeFade
            edgeFade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
            edgeFade.locations = [0, NSNumber(value: fade), NSNumber(value: 1 - fade), 1]
            edgeFade.startPoint = CGPoint(x: 0, y: 0.5)
            edgeFade.endPoint = CGPoint(x: 1, y: 0.5)
            bgImageView.layer.mask = edgeFade
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard DeviceLayout.isPad else { return }
        // The mask covers exactly where the picture is drawn (aspect fit), not the whole image view.
        let bounds = bgImageView.bounds
        var drawn = bounds
        if let size = bgImageView.image?.size, size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 {
            let scale = min(bounds.width / size.width, bounds.height / size.height)
            let width = size.width * scale
            let height = size.height * scale
            drawn = CGRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2, width: width, height: height)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        edgeFade.frame = drawn
        CATransaction.commit()
    }

    func configure(with page: OnboardingPage) {
        bgImageView.image = UIImage(named: page.background)
        iconImageView.image = UIImage(named: page.icon)
        titleLabel.text = page.title
        descriptionLabel.text = page.description
    }
}
