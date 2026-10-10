import UIKit

/// The quality choices (480p, 720p, 1080p) as a row of chips that scrolls sideways. The chips for 720p and
/// 1080p carry the crown from the design while the user is not Premium; the crown goes away once they are.
/// Styled like `FeedbackChipsView`: the chosen chip has a blue outline.
final class MirrorQualityChips: UIView {

    private static let chipHeight: CGFloat = DeviceLayout.s(40)
    private static let spacing: CGFloat = 12

    private(set) var selected: MirrorShared.Quality
    /// Called after the user picks a chip.
    var onChange: ((MirrorShared.Quality) -> Void)?

    private let scrollView = UIScrollView()
    private var chips: [MirrorShared.Quality: HapticButton] = [:]

    init(selected: MirrorShared.Quality) {
        self.selected = selected
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.chipHeight).isActive = true
        build()
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshCrowns), name: SubscriptionManager.didChangeNotification, object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("MirrorQualityChips is built in code")
    }

    /// While a broadcast runs the quality can't change: the chips stay as they are but can't be tapped, and look
    /// dimmed. Stop the broadcast first.
    func setLocked(_ isLocked: Bool) {
        for chip in chips.values {
            chip.isEnabled = !isLocked
            chip.accessibilityTraits = isLocked ? [.button, .notEnabled] : .button
        }
        UIView.animate(withDuration: 0.2) {
            self.scrollView.alpha = isLocked ? 0.5 : 1
        }
    }

    func select(_ quality: MirrorShared.Quality) {
        selected = quality
        for (option, chip) in chips {
            style(chip, selected: option == quality)
        }
    }

    // MARK: - Building

    private func build() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Self.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        for quality in MirrorShared.Quality.allCases {
            let chip = makeChip(quality)
            chips[quality] = chip
            stack.addArrangedSubview(chip)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    private func makeChip(_ quality: MirrorShared.Quality) -> HapticButton {
        let chip = HapticButton(type: .custom)
        chip.setTitle(quality.title, for: .normal)
        chip.setTitleColor(CommonColor.white.color, for: .normal)
        chip.titleLabel?.font = CommonFont.semibold.font(ofSize: 15)
        applyCrown(to: chip, for: quality)
        chip.layer.cornerRadius = Self.chipHeight / 2
        chip.layer.borderWidth = 1.5
        chip.accessibilityLabel = quality.title
        chip.accessibilityTraits = .button
        chip.addAction(UIAction { [weak self] _ in self?.choose(quality) }, for: .touchUpInside)
        chip.heightAnchor.constraint(equalToConstant: Self.chipHeight).isActive = true
        style(chip, selected: quality == selected)
        return chip
    }

    /// The crown after the title of a Premium quality, for a user who is not Premium; nothing otherwise.
    private func applyCrown(to chip: UIButton, for quality: MirrorShared.Quality) {
        if quality.isPremium, !SubscriptionManager.shared.isPremium, let crown = UIImage(named: "premium") {
            chip.setImage(Self.resized(crown, to: 18), for: .normal)
            // The crown sits after the title.
            chip.semanticContentAttribute = .forceRightToLeft
            chip.imageEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
            chip.contentEdgeInsets = UIEdgeInsets(top: 0, left: 22, bottom: 0, right: 22)
        } else {
            chip.setImage(nil, for: .normal)
            chip.semanticContentAttribute = .unspecified
            chip.imageEdgeInsets = .zero
            chip.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
    }

    /// Premium turned on or off: add or remove the crowns.
    @objc private func refreshCrowns() {
        for (quality, chip) in chips {
            applyCrown(to: chip, for: quality)
        }
    }

    private func style(_ chip: UIButton, selected: Bool) {
        chip.backgroundColor = selected ? UIColor(hex: 0x0A2A6B).withAlphaComponent(0.6) : UIColor(hex: 0x131B2E)
        chip.layer.borderColor = (selected ? UIColor(hex: 0x004BF9) : UIColor.clear).cgColor
        chip.accessibilityValue = selected ? "Selected" : "Not selected"
    }

    private func choose(_ quality: MirrorShared.Quality) {
        guard quality != selected else { return }
        select(quality)
        onChange?(quality)
    }

    /// The crown at a fixed height, whatever size the asset was exported at.
    private static func resized(_ image: UIImage, to height: CGFloat) -> UIImage {
        guard image.size.height > 0 else { return image }
        let size = CGSize(width: image.size.width * height / image.size.height, height: height)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }
}
