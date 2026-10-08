import UIKit

/// One option card of the Cast screen: a dark card with an icon and a title, as in the Figma
/// "Cast Media" section. The icon is just the image from the asset catalog, so it can be swapped there.
/// It is a `HapticButton`, so a tap already gives feedback.
final class CastOptionCard: HapticButton {

    enum Layout {
        /// Icon above the title: the Photo and Video cards.
        case vertical
        /// Icon then title in a row: the Files card.
        case horizontal
    }

    private static let iconSize: CGFloat = 60

    private let layout: Layout

    init(title: String, glyph: String, layout: Layout) {
        self.layout = layout
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(hex: 0x10182C)
        layer.cornerRadius = 16
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(hex: 0x434F68).cgColor
        clipsToBounds = true
        accessibilityLabel = title

        let tile = UIImageView(image: UIImage(named: glyph))
        tile.contentMode = .scaleAspectFit
        tile.isUserInteractionEnabled = false
        tile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: Self.iconSize),
            tile.heightAnchor.constraint(equalToConstant: Self.iconSize)
        ])
        let label = UILabel()
        label.attributedText = NSAttributedString(string: title, attributes: [
            .font: CommonFont.bold.font(ofSize: 15),
            .foregroundColor: CommonColor.white.color,
            .kern: 0.3
        ])
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tile)
        addSubview(label)

        switch layout {
        case .vertical:
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 129),
                tile.centerXAnchor.constraint(equalTo: centerXAnchor),
                tile.topAnchor.constraint(equalTo: topAnchor, constant: 23.5),
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.topAnchor.constraint(equalTo: tile.bottomAnchor, constant: 11)
            ])
        case .horizontal:
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 107),
                tile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 21.5),
                tile.centerYAnchor.constraint(equalTo: centerYAnchor),
                label.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: 11),
                label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
                label.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("CastOptionCard is built in code")
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.45 }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isEnabled ? (isHighlighted ? 0.8 : 1) : 0.45 }
    }
}
