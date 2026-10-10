import CoreImage
import UIKit

/// One TV in the history list: icon, name, address and a green / red online dot.
final class HistoryCell: UITableViewCell, ReusableCell {

    private let card = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let defaultLabel = UILabel()
    private let defaultBadge = UIView()
    private let addressLabel = UILabel()
    private let dot = UIView()
    /// A blurred picture of the card, for a TV that is behind Premium, with a lock and text on top (sharp).
    private let lockBlur = UIImageView()
    private let lockBadge = UIStackView()
    private var isLocked = false
    private var blurredSize: CGSize = .zero
    private var blurredHost: String?
    private nonisolated static let ciContext = CIContext()
    /// Gaussian blur radius in pixels. Higher is blurrier.
    private nonisolated static let blurRadius: CGFloat = 4

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// `isOnline` is nil while the check is still running: the dot stays grey.
    /// `isLocked` blurs the card (a TV behind Premium) and shows a lock with text on it.
    func configure(with tv: SavedTV, isOnline: Bool?, isLocked: Bool = false) {
        self.isLocked = isLocked
        if tv.host != blurredHost {
            // A different TV (the cell was reused): never show the old picture.
            lockBlur.image = nil
            blurredHost = tv.host
        }
        // Locked: cover the card straight away, so the sharp row is never seen while the blur is made.
        lockBlur.isHidden = !isLocked
        lockBadge.isHidden = !isLocked
        blurredSize = .zero
        isAccessibilityElement = isLocked
        accessibilityLabel = isLocked ? "Locked. Premium required." : nil
        nameLabel.text = tv.device.name
        addressLabel.text = tv.host
        defaultBadge.isHidden = tv.isDefault != true
        switch isOnline {
        case .some(true): dot.backgroundColor = UIColor(hex: 0x1FB84A)
        case .some(false): dot.backgroundColor = UIColor(hex: 0xE5252A)
        case .none: dot.backgroundColor = UIColor(hex: 0x707A91)
        }
        refreshBlur()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if isLocked, card.bounds.size != blurredSize { refreshBlur() }
    }

    /// Takes a picture of the card (without the cover and the lock) on the main thread, blurs it on a
    /// background queue (`ThreadManager`) and shows it over the card. A real blur radius, so the row is
    /// clearly blurred but its shapes can still be seen. Until the picture is ready the cover is the
    /// card's own colour.
    private func refreshBlur() {
        guard isLocked else {
            lockBlur.isHidden = true
            lockBlur.image = nil
            return
        }
        let size = card.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        blurredSize = size

        let wasHidden = (lockBlur.isHidden, lockBadge.isHidden)
        lockBlur.isHidden = true
        lockBadge.isHidden = true
        let picture = UIGraphicsImageRenderer(size: size).image { card.layer.render(in: $0.cgContext) }
        (lockBlur.isHidden, lockBadge.isHidden) = wasHidden

        let host = blurredHost
        // @Sendable: this closure runs off the main thread.
        let blur: @Sendable () -> UIImage? = { Self.blurred(picture) }
        ThreadManager.runAsync(work: blur) { [weak self] result in
            guard let self, self.isLocked, self.blurredHost == host,
                  case .success(let image?) = result else { return }
            self.lockBlur.image = image
        }
    }

    /// The Gaussian blur of `picture`. Safe off the main thread.
    private nonisolated static func blurred(_ picture: UIImage) -> UIImage? {
        guard let input = CIImage(image: picture),
              let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(blurRadius * picture.scale, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent),
              let cgImage = ciContext.createCGImage(output, from: input.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: picture.scale, orientation: .up)
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.backgroundColor = UIColor(hex: 0x10182C)
        card.layer.cornerRadius = DeviceLayout.s(20)
        card.layer.borderWidth = 1.5
        card.layer.borderColor = UIColor(hex: 0x202A40).cgColor

        // ic_tv already includes the round blue background.
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(named: "ic_tv")

        nameLabel.font = CommonFont.semibold.font(ofSize: 14)
        nameLabel.textColor = CommonColor.white.color
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.numberOfLines = 1
        nameLabel.setContentHuggingPriority(.init(251), for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        defaultLabel.text = "Default"
        defaultLabel.font = CommonFont.semibold.font(ofSize: 10)
        defaultLabel.textColor = CommonColor.white.color
        defaultLabel.translatesAutoresizingMaskIntoConstraints = false
        defaultBadge.backgroundColor = UIColor(hex: 0x004BF9)
        defaultBadge.layer.cornerRadius = DeviceLayout.s(9)
        defaultBadge.addSubview(defaultLabel)
        NSLayoutConstraint.activate([
            defaultLabel.topAnchor.constraint(equalTo: defaultBadge.topAnchor, constant: DeviceLayout.s(3)),
            defaultLabel.bottomAnchor.constraint(equalTo: defaultBadge.bottomAnchor, constant: -DeviceLayout.s(3)),
            defaultLabel.leadingAnchor.constraint(equalTo: defaultBadge.leadingAnchor, constant: DeviceLayout.s(8)),
            defaultLabel.trailingAnchor.constraint(equalTo: defaultBadge.trailingAnchor, constant: -DeviceLayout.s(8))
        ])
        defaultBadge.setContentHuggingPriority(.required, for: .horizontal)
        defaultBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        addressLabel.font = CommonFont.medium.font(ofSize: 12)
        addressLabel.textColor = UIColor(hex: 0x707A91)

        dot.layer.cornerRadius = DeviceLayout.s(4)
        dot.isAccessibilityElement = false

        // Soaks up the free width so the badge stays right after the name.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        let nameRow = UIStackView(arrangedSubviews: [nameLabel, defaultBadge, spacer])
        nameRow.alignment = .center
        nameRow.spacing = 6
        let texts = UIStackView(arrangedSubviews: [nameRow, addressLabel])
        texts.axis = .vertical
        texts.spacing = 4

        [card, iconView, texts, dot].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        contentView.addSubview(card)
        [iconView, texts, dot].forEach { card.addSubview($0) }

        lockBlur.contentMode = .scaleToFill
        // The cover until the blurred picture is ready: the card's own colour.
        lockBlur.backgroundColor = UIColor(hex: 0x10182C)
        lockBlur.layer.cornerRadius = DeviceLayout.s(20)
        lockBlur.clipsToBounds = true
        lockBlur.isHidden = true

        let lockIcon = UIImageView(image: UIImage(named: "lock") ?? UIImage(systemName: "lock.fill"))
        lockIcon.tintColor = CommonColor.white.color
        lockIcon.contentMode = .scaleAspectFit
        let lockText = UILabel()
        lockText.text = "Unlock with Premium"
        lockText.font = CommonFont.semibold.font(ofSize: 14)
        lockText.textColor = CommonColor.white.color
        [lockIcon, lockText].forEach { lockBadge.addArrangedSubview($0) }
        lockBadge.alignment = .center
        lockBadge.spacing = 8
        lockBadge.isHidden = true
        [lockBlur, lockBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        NSLayoutConstraint.activate([
            lockBlur.topAnchor.constraint(equalTo: card.topAnchor),
            lockBlur.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            lockBlur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            lockBlur.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            lockIcon.widthAnchor.constraint(equalToConstant: DeviceLayout.s(24)),
            lockIcon.heightAnchor.constraint(equalToConstant: DeviceLayout.s(24)),
            lockBadge.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            lockBadge.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DeviceLayout.s(6)),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DeviceLayout.s(6)),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DeviceLayout.s(16)),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DeviceLayout.s(16)),
            card.heightAnchor.constraint(equalToConstant: DeviceLayout.s(76)),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DeviceLayout.s(10)),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: DeviceLayout.s(44)),
            iconView.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44)),

            texts.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DeviceLayout.s(12)),
            texts.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            texts.trailingAnchor.constraint(equalTo: dot.leadingAnchor, constant: -DeviceLayout.s(12)),

            dot.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DeviceLayout.s(16)),
            dot.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: DeviceLayout.s(8)),
            dot.heightAnchor.constraint(equalToConstant: DeviceLayout.s(8))
        ])
    }
}
