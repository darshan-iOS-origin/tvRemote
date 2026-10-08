import UIKit

/// One option card of the Cast screen: a dark card with a coloured icon tile and a title, as in the Figma
/// "Cast Media" section. It is a `HapticButton`, so a tap already gives feedback.
final class CastOptionCard: HapticButton {

    enum Layout {
        /// Tile above the title: the Photo and Video cards.
        case vertical
        /// Tile then title in a row: the Files card.
        case horizontal
    }

    private static let tileSize: CGFloat = 60
    private static let squareSize: CGFloat = 42.857
    private static let squareRadius: CGFloat = 8.486

    private let layout: Layout

    /// - Parameters:
    ///   - color: the colour of the back square of the icon tile.
    ///   - glyph: name of the white glyph in the asset catalog.
    ///   - glyphOffset: how far the glyph sits from the middle of the tile (Figma: it rides on the front square).
    init(title: String, color: UIColor, glyph: String, glyphOffset: CGPoint, layout: Layout) {
        self.layout = layout
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(hex: 0x10182C)
        layer.cornerRadius = 16
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(hex: 0x434F68).cgColor
        clipsToBounds = true
        accessibilityLabel = title

        let tile = makeTile(color: color, glyph: glyph, glyphOffset: glyphOffset)
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

    /// The 60x60 tile: a coloured rounded square, a frosted white one offset to its right, and the glyph.
    private func makeTile(color: UIColor, glyph: String, glyphOffset: CGPoint) -> UIView {
        let tile = UIView()
        tile.isUserInteractionEnabled = false
        tile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: Self.tileSize),
            tile.heightAnchor.constraint(equalToConstant: Self.tileSize)
        ])

        let back = UIView(frame: CGRect(x: 3.43, y: 8.57, width: Self.squareSize, height: Self.squareSize))
        back.backgroundColor = color
        back.layer.cornerRadius = Self.squareRadius

        let front = UIView(frame: CGRect(x: 13.71, y: 8.57, width: Self.squareSize, height: Self.squareSize))
        front.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        front.layer.cornerRadius = Self.squareRadius

        let icon = UIImageView(image: UIImage(named: glyph))
        icon.contentMode = .scaleAspectFit
        icon.sizeToFit()
        icon.center = CGPoint(x: Self.tileSize / 2 + glyphOffset.x, y: Self.tileSize / 2 + glyphOffset.y)

        [back, front, icon].forEach(tile.addSubview)
        return tile
    }
}
