import UIKit

/// Last onboarding page: title, description and a 2-column grid of TV brand images.
/// Exactly one brand can be selected; the selected tile gets a 2pt primary blue border.
final class OnboardingBrandCell: UICollectionViewCell {

    static let reuseIdentifier = "OnboardingBrandCell"

    /// Space reserved below the grid for the pager dots and Continue button.
    private let bottomInset: CGFloat = DeviceLayout.isPad ? 150 : 130
    private let spacing: CGFloat = 16
    private let columns = 2
    /// The brand images are 167 x 104.
    private let tileAspect: CGFloat = 104.0 / 167.0

    /// iPad: the grid is as wide as the free height allows (set in `layoutSubviews`), so all rows fit and each tile
    /// keeps its image's shape. Nil on iPhone.
    private var gridWidth: NSLayoutConstraint?

    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let gridStack = UIStackView()

    private var tiles: [BrandTileButton] = []
    private var selectedID: String?

    var onBrandSelected: ((BrandOption) -> Void)?

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
        titleLabel.font = CommonFont.bold.font(ofSize: 26)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .left

        descriptionLabel.text = OnboardingPage.brandDescription
        descriptionLabel.font = CommonFont.regular.font(ofSize: 15)
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
            titleLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 40),

            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),

            gridStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 50)
        ])

        if DeviceLayout.isPad {
            // Centred grid with a computed width; the title lines up with its left edge.
            let width = gridStack.widthAnchor.constraint(equalToConstant: 0)
            gridWidth = width
            NSLayoutConstraint.activate([
                gridStack.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
                width,
                titleLabel.leadingAnchor.constraint(equalTo: gridStack.leadingAnchor),
                titleLabel.trailingAnchor.constraint(equalTo: gridStack.trailingAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
                titleLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
                gridStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
                gridStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
                gridStack.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -bottomInset)
            ])
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard DeviceLayout.isPad, let gridWidth else { return }
        let safe = contentView.safeAreaLayoutGuide.layoutFrame
        let rows = CGFloat((BrandOption.all.count + columns - 1) / columns)
        // Free height under the description, above the pager and the Continue button.
        let freeHeight = safe.maxY - bottomInset - gridStack.frame.minY
        let tileByHeight = (freeHeight - spacing * (rows - 1)) / (rows * tileAspect)
        let widthLimit = min(safe.width - 32, DeviceLayout.padBrandGridMaxWidth)
        let tileByWidth = (widthLimit - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let tile = floor(max(80, min(tileByHeight, tileByWidth)))
        let width = tile * CGFloat(columns) + spacing * CGFloat(columns - 1)
        if abs(gridWidth.constant - width) > 0.5 {
            gridWidth.constant = width
            setNeedsLayout()
        }
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
                tile.addAction(UIAction { [weak self] _ in self?.select(option) }, for: .touchUpInside)
                tiles.append(tile)
                row.addArrangedSubview(tile)
            }
            gridStack.addArrangedSubview(row)
            index += columns
        }
    }

    private func select(_ option: BrandOption) {
        guard selectedID != option.id else { return }
        selectedID = option.id
        applyState()
        onBrandSelected?(option)
    }

    private func applyState() {
        tiles.forEach { $0.setSelectedState($0.option.id == selectedID) }
    }

    func configure(selectedID: String?) {
        self.selectedID = selectedID
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
