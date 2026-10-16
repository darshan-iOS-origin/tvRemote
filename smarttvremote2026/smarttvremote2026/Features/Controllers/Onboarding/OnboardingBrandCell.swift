import UIKit

/// Last onboarding page: title, description and a 2-column grid of TV brand images.
/// Exactly one brand can be selected; the selected tile gets a 2pt primary blue border.
final class OnboardingBrandCell: UICollectionViewCell {

    static let reuseIdentifier = "OnboardingBrandCell"

    /// Space reserved below the grid for the pager dots and Continue button.
    private let bottomInset: CGFloat = DeviceLayout.isPad ? 150 : 130
    private let spacing: CGFloat = 16
    private let titleTopInset: CGFloat = 40
    private let gridTopGap: CGFloat = 50
    private let columns = 2
    /// The brand images are 167 x 104.
    private let tileAspect: CGFloat = 104.0 / 167.0

    /// The grid is as wide as the free height allows (set in `layoutSubviews`), so all rows fit under the title and
    /// each tile keeps its image's shape. Small iPhones (SE) get smaller tiles; larger ones fill the width.
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
        titleLabel.numberOfLines = 2

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
            titleLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: titleTopInset),

            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),

            gridStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: gridTopGap)
        ])

        // Centred grid with a computed width (see `layoutSubviews`); the title lines up with its left edge.
        let width = gridStack.widthAnchor.constraint(equalToConstant: 0)
        gridWidth = width
        NSLayoutConstraint.activate([
            gridStack.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            width,
            titleLabel.leadingAnchor.constraint(equalTo: gridStack.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: gridStack.trailingAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let gridWidth else { return }
        let safe = contentView.safeAreaLayoutGuide.layoutFrame
        let rows = CGFloat((BrandOption.all.count + columns - 1) / columns)
        let widthLimit = DeviceLayout.isPad ? min(safe.width - 32, DeviceLayout.padBrandGridMaxWidth) : safe.width - 32
        let tileByWidth = (widthLimit - spacing * CGFloat(columns - 1)) / CGFloat(columns)

        // The title and description are as wide as the grid, so their height (and where the grid starts) depends on
        // the grid width. Work that out here instead of reading the grid's frame, which is one pass behind.
        var width = widthLimit
        for _ in 0..<3 {
            let textWidth = max(width, 1)
            let titleHeight = titleLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
            let descriptionHeight = descriptionLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
            let gridTop = safe.minY + titleTopInset + titleHeight + 6 + descriptionHeight + gridTopGap
            // Free height under the description, above the pager and the Continue button.
            let freeHeight = safe.maxY - bottomInset - gridTop
            let tileByHeight = (freeHeight - spacing * (rows - 1)) / (rows * tileAspect)
            let tile = floor(max(80, min(tileByHeight, tileByWidth)))
            width = tile * CGFloat(columns) + spacing * CGFloat(columns - 1)
        }
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
                tile.addAction(UIAction { [weak self] _ in
                    if let event = FirebaseEvents.Tap.onboardingBrand[option.id] {
                        AnalyticsManager.shared.log(event)
                    }
                    self?.select(option)
                }, for: .touchUpInside)
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
