import UIKit

/// "App Icon": a large preview of the chosen icon, a card with the six icons, and an Apply button.
/// Picking a tile only changes the preview and the radio; Apply changes the real icon.
/// Built in code; open it with `NavigationManager.showAppIcon(from:)`.
final class AppIconVC: UIViewController {

    private let backButton = HapticButton(type: .custom)
    private let titleLabel = UILabel()
    private let previewView = UIImageView()
    private let applyButton = HapticButton(type: .custom)
    private var tiles: [AppIconTile] = []
    private var selected = AppIconManager.current

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
        updateSelection()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
    }

    // MARK: - Layout

    private func setupViews() {
        backButton.applyBackArrowStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)

        titleLabel.text = "App Icon"
        titleLabel.font = CommonFont.semibold.font(ofSize: 16)
        titleLabel.textColor = CommonColor.white.color

        previewView.contentMode = .scaleAspectFill
        previewView.layer.cornerRadius = 26
        previewView.clipsToBounds = true

        let heading = UILabel()
        heading.text = "App Icon"
        heading.font = CommonFont.bold.font(ofSize: 20)
        heading.textColor = CommonColor.white.color
        heading.textAlignment = .center

        let card = UIView()
        card.backgroundColor = UIColor(hex: 0x10182C)
        card.layer.cornerRadius = 24
        card.layer.borderWidth = 1.5
        card.layer.borderColor = UIColor(hex: 0x202A40).cgColor

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 20
        grid.distribution = .fillEqually
        let options = AppIconManager.options
        for rowStart in stride(from: 0, to: options.count, by: 3) {
            let row = UIStackView()
            row.distribution = .fillEqually
            for option in options[rowStart..<min(rowStart + 3, options.count)] {
                let tile = AppIconTile(option: option)
                tile.addAction(UIAction { [weak self] _ in self?.select(option) }, for: .touchUpInside)
                tiles.append(tile)
                row.addArrangedSubview(tile)
            }
            grid.addArrangedSubview(row)
        }

        applyButton.setTitle("Apply", for: .normal)
        applyButton.setTitleColor(CommonColor.white.color, for: .normal)
        applyButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        applyButton.backgroundColor = UIColor(hex: 0x004BF9)
        applyButton.addTarget(self, action: #selector(onTap_apply), for: .touchUpInside)

        [backButton, titleLabel, previewView, heading, card, applyButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        grid.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(grid)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            previewView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 24),
            previewView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewView.widthAnchor.constraint(equalToConstant: DeviceLayout.s(100)),
            previewView.heightAnchor.constraint(equalToConstant: DeviceLayout.s(100)),

            heading.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 16),
            heading.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            heading.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            card.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 24),
            card.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            grid.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            grid.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            grid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            applyButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            applyButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            applyButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            applyButton.heightAnchor.constraint(equalToConstant: LottieManager.buttonHeight)
        ])
        LottieManager.applyButtonBackground(to: applyButton)
    }

    // MARK: - Actions

    private func select(_ option: AppIconOption) {
        guard option != selected else { return }
        selected = option
        updateSelection()
    }

    private func updateSelection() {
        previewView.image = UIImage(named: selected.previewName)
        tiles.forEach { $0.setSelected($0.option == selected) }
    }

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func onTap_apply() {
        // Changing the app icon is a Premium feature: a free user gets the "Unlock Custom Icons" sheet.
        guard SubscriptionManager.shared.isPremium else {
            AppIconSheetVC.presentIfFree(from: self)
            return
        }
        guard selected != AppIconManager.current else { return }
        AppIconManager.apply(selected) { [weak self] message in
            if let message { self?.showSimpleAlert(title: "App Icon", message: message) }
        }
    }
}

/// One icon in the grid, with its radio under it.
private final class AppIconTile: UIControl {

    let option: AppIconOption
    private let radioDot = UIView()
    private let radioRing = UIView()

    init(option: AppIconOption) {
        self.option = option
        super.init(frame: .zero)

        let icon = UIImageView(image: UIImage(named: option.previewName))
        icon.contentMode = .scaleAspectFill
        icon.layer.cornerRadius = 16
        icon.clipsToBounds = true
        icon.isUserInteractionEnabled = false

        radioRing.layer.cornerRadius = 11
        radioRing.layer.borderWidth = 2
        radioRing.isUserInteractionEnabled = false
        radioDot.backgroundColor = UIColor(hex: 0x004BF9)
        radioDot.layer.cornerRadius = 5
        radioDot.isUserInteractionEnabled = false

        [icon, radioRing, radioDot].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: topAnchor),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: DeviceLayout.s(64)),
            icon.heightAnchor.constraint(equalToConstant: DeviceLayout.s(64)),

            radioRing.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 10),
            radioRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            radioRing.widthAnchor.constraint(equalToConstant: DeviceLayout.s(22)),
            radioRing.heightAnchor.constraint(equalToConstant: DeviceLayout.s(22)),
            radioRing.bottomAnchor.constraint(equalTo: bottomAnchor),

            radioDot.centerXAnchor.constraint(equalTo: radioRing.centerXAnchor),
            radioDot.centerYAnchor.constraint(equalTo: radioRing.centerYAnchor),
            radioDot.widthAnchor.constraint(equalToConstant: DeviceLayout.s(10)),
            radioDot.heightAnchor.constraint(equalToConstant: DeviceLayout.s(10))
        ])
        isAccessibilityElement = true
        accessibilityLabel = "App icon \(option.id)"
        accessibilityTraits = .button
        addAction(UIAction { _ in HapticManager.trigger(.light) }, for: .touchUpInside)
        setSelected(false)
    }

    required init?(coder: NSCoder) {
        fatalError("AppIconTile is built in code")
    }

    func setSelected(_ isSelected: Bool) {
        radioDot.isHidden = !isSelected
        radioRing.layer.borderColor = (isSelected ? UIColor(hex: 0x004BF9) : UIColor(hex: 0x707A91)).cgColor
        accessibilityValue = isSelected ? "Selected" : "Not selected"
    }
}
