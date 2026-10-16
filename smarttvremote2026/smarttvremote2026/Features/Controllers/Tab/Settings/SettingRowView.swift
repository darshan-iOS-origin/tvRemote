import UIKit

/// One row of a Settings card: a 30x30 icon, a white title and either a chevron or a muted value.
final class SettingRowView: UIControl {

    static let iconSize: CGFloat = DeviceLayout.isPad ? DeviceLayout.padSettingsIconSize : 30
    static let height: CGFloat = DeviceLayout.isPad ? DeviceLayout.padSettingsRowHeight : 58
    /// Space inside the row at its left and right edges.
    private static let padding: CGFloat = DeviceLayout.isPad ? DeviceLayout.padSettingsRowPadding : 16
    /// Title / value text size (before the iPad font scale).
    private static let textSize: CGFloat = DeviceLayout.isPad ? DeviceLayout.padSettingsRowFontSize : 15

    /// What the row shows on its right side.
    enum Accessory {
        case chevron
        case value(String)
    }

    private let onTap: (() -> Void)?

    /// `iconName` is an asset; `fallbackSymbol` is an SF Symbol used while the asset is missing.
    init(iconName: String, fallbackSymbol: String? = nil, title: String, accessory: Accessory, onTap: (() -> Void)? = nil) {
        self.onTap = onTap
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true

        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        if let image = UIImage(named: iconName) {
            iconView.image = image
        } else if let fallbackSymbol {
            iconView.image = IconsHelper.image(systemName: fallbackSymbol, pointSize: DeviceLayout.isPad ? 26 : 20)
            iconView.tintColor = CommonColor.white.color
        }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = CommonFont.semibold.font(ofSize: Self.textSize)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.isUserInteractionEnabled = false

        let trailing: UIView
        switch accessory {
        case .chevron:
            let chevron = UIImageView(image: IconsHelper.image(systemName: "chevron.right", pointSize: DeviceLayout.isPad ? 16 : 12))
            chevron.tintColor = UIColor(hex: 0x707A91)
            chevron.contentMode = .scaleAspectFit
            trailing = chevron
        case .value(let text):
            let label = UILabel()
            label.text = text
            label.font = CommonFont.semibold.font(ofSize: Self.textSize)
            label.textColor = UIColor(hex: 0x707A91)
            trailing = label
        }
        trailing.isUserInteractionEnabled = false
        trailing.setContentHuggingPriority(.required, for: .horizontal)

        [iconView, titleLabel, trailing].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.padding),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.iconSize),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailing.leadingAnchor, constant: -8),

            trailing.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.padding),
            trailing.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        isAccessibilityElement = true
        accessibilityLabel = title
        if case .value(let text) = accessory { accessibilityValue = text }
        if case .chevron = accessory { accessibilityTraits = .button } else { accessibilityTraits = .staticText }
        addTarget(self, action: #selector(onTap_row), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("SettingRowView is built in code")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    @objc private func onTap_row() {
        HapticManager.trigger(.light)
        onTap?()
    }
}
