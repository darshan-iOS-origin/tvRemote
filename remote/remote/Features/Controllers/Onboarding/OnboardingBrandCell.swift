import UIKit

/// Last onboarding page: title, description and a 2-column grid of TV brand images.
/// Exactly one brand can be selected; the selected tile gets a 2pt primary blue border.
final class OnboardingBrandCell: UICollectionViewCell {

    static let reuseIdentifier = "OnboardingBrandCell"

    /// Space reserved below the grid for the pager dots and Continue button.
    private let bottomInset: CGFloat = 130
    private let spacing: CGFloat = 16
    private let columns = 2

    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let gridStack = UIStackView()

    private var tiles: [BrandTileButton] = []
    private var selectedBrand: TVBrand?

    var onBrandSelected: ((TVBrand) -> Void)?

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

        titleLabel.text = OnboardingPage.brandTitle
        titleLabel.font = UIFont(name: "SFProText-Bold", size: 26) ?? .boldSystemFont(ofSize: 26)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .left

        descriptionLabel.text = OnboardingPage.brandDescription
        descriptionLabel.font = UIFont(name: "SFProText-Regular", size: 15) ?? .systemFont(ofSize: 15)
        descriptionLabel.textColor = CommonColor.secondaryGray.color
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 0

        gridStack.axis = .vertical
        gridStack.spacing = spacing
        gridStack.distribution = .fillEqually

        buildGrid()

        [titleLabel, descriptionLabel, gridStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        let safe = contentView.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 40),

            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),

            gridStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            gridStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            gridStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 50),
            gridStack.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -bottomInset)
        ])
    }

    private func buildGrid() {
        let options = BrandOption.all
        var index = 0
        while index < options.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = spacing
            row.distribution = .fillEqually
            for option in options[index..<min(index + columns, options.count)] {
                let tile = BrandTileButton(option: option)
                tile.addAction(UIAction { [weak self] _ in self?.select(option.brand) }, for: .touchUpInside)
                tiles.append(tile)
                row.addArrangedSubview(tile)
            }
            gridStack.addArrangedSubview(row)
            index += columns
        }
    }

    private func select(_ brand: TVBrand) {
        guard selectedBrand != brand else { return }
        selectedBrand = brand
        applyState()
        onBrandSelected?(brand)
    }

    private func applyState() {
        tiles.forEach { $0.setSelectedState($0.option.brand == selectedBrand) }
    }

    func configure(selected: TVBrand?) {
        selectedBrand = selected
        applyState()
    }
}

/// One tappable brand image. The image is shown as-is; only the container draws the selection border.
private final class BrandTileButton: HapticButton {

    let option: BrandOption
    private let imageContainer = UIImageView()

    init(option: BrandOption) {
        self.option = option
        super.init(frame: .zero)
        imageContainer.image = UIImage(named: option.imageName)
        imageContainer.contentMode = .scaleAspectFit
        imageContainer.isUserInteractionEnabled = false
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageContainer)

        layer.cornerRadius = 12
        layer.borderColor = CommonColor.primaryBlue.color.cgColor
        layer.borderWidth = 0

        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: topAnchor),
            imageContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            // Assets are 167x104.
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 104.0 / 167.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setSelectedState(_ isSelected: Bool) {
        layer.borderWidth = isSelected ? 2 : 0
    }
}
