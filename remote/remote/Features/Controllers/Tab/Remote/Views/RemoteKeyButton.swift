import UIKit

/// One key of the on-screen remote, in the Figma look: a rounded surface (dark box, gradient or tint)
/// with a border, an optional icon and an optional title. It is a `HapticButton`, so every tap already
/// gives feedback. Leave `cornerRadius` nil for a circle (or capsule).
final class RemoteKeyButton: HapticButton {

    enum Fill {
        case clear
        case box
        case linear(top: UIColor, bottom: UIColor)
        /// A soft tint, drawn at `opacity` over the screen background.
        case radial(RemoteGradientView.Radial, opacity: CGFloat)
    }

    enum Icon {
        case image(String, transform: CGAffineTransform = .identity)
        /// Several glyphs stacked in one 28 pt slot, each centred at the given point of the slot.
        case layers([(name: String, center: CGPoint)])
        /// A small round colour swatch.
        case dot(top: UIColor, bottom: UIColor)
    }

    enum Layout {
        /// Icon and title centred together (either one may be missing).
        case centered
        /// Icon near the top, title under it: the card keys.
        case iconAbove(spacing: CGFloat)
        /// Icon then title in a row, moved sideways by `offsetX`.
        case iconBeside(spacing: CGFloat, offsetX: CGFloat)
    }

    private static let iconSlot: CGFloat = 28
    private static let dotSize: CGFloat = 16
    /// Distance from the top edge to the icon in the card keys (15 pt padding + 1.5 pt border).
    private static let cardIconTop: CGFloat = 16.5
    /// Figma trims the title to its cap height; this is half of it, to place the title's centre.
    private static let titleCenterOffset: CGFloat = 4

    /// The TV key this button sends. Nil for a button that does nothing yet.
    var key: KeyCommand?
    /// Called with `key` on a tap, or again and again while held when `repeatsWhileHeld` is set.
    var onKey: ((KeyCommand) -> Void)?
    var repeatsWhileHeld = false

    private static let repeatDelay: TimeInterval = 0.4
    private static let repeatInterval: TimeInterval = 0.2

    private let surface = UIView()
    private let fixedCornerRadius: CGFloat?
    private var repeatTimer: Timer?

    init(
        icon: Icon? = nil,
        title: String? = nil,
        font: UIFont = CommonFont.semibold.font(ofSize: 14),
        layout: Layout = .centered,
        fill: Fill = .box,
        borderColor: UIColor = RemoteTheme.border,
        borderWidth: CGFloat = RemoteTheme.keyBorderWidth,
        cornerRadius: CGFloat? = nil,
        shadowed: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        fixedCornerRadius = cornerRadius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        surface.isUserInteractionEnabled = false
        surface.clipsToBounds = true
        surface.layer.borderWidth = borderWidth
        surface.layer.borderColor = borderColor.cgColor
        addSubview(surface)
        surface.pinEdges(to: self)
        applyFill(fill)

        buildContent(icon: icon, title: title, font: font, layout: layout)

        if shadowed {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.42
            layer.shadowOffset = CGSize(width: 0, height: 1.8)
            layer.shadowRadius = 3.6
        }
        if let width { widthAnchor.constraint(equalToConstant: width).isActive = true }
        if let height { heightAnchor.constraint(equalToConstant: height).isActive = true }

        addTarget(self, action: #selector(onTouchDown), for: .touchDown)
        addTarget(self, action: #selector(onTouchUp), for: .touchUpInside)
        addTarget(self, action: #selector(onTouchEnd), for: [.touchUpOutside, .touchCancel, .touchDragExit])
    }

    @MainActor
    deinit {
        repeatTimer?.invalidate()
    }

    required init?(coder: NSCoder) {
        fatalError("RemoteKeyButton is built in code")
    }

    /// Sets the key this button sends and what to do with it.
    func bind(_ key: KeyCommand, repeats: Bool = false, handler: @escaping (KeyCommand) -> Void) {
        self.key = key
        repeatsWhileHeld = repeats
        onKey = handler
    }

    /// Dims a key the connected TV does not have, and stops it from being pressed.
    func setAvailable(_ available: Bool) {
        isEnabled = available
        surface.alpha = available ? 1 : 0.4
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = fixedCornerRadius ?? min(bounds.width, bounds.height) / 2
        surface.layer.cornerRadius = radius
        if layer.shadowOpacity > 0 {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        }
    }

    // MARK: - Presses

    @objc private func onTouchDown() {
        guard repeatsWhileHeld, let key else { return }
        onKey?(key)
        stopRepeating()
        let first = Timer(timeInterval: Self.repeatDelay, repeats: false) { [weak self] _ in
            self?.startRepeating()
        }
        schedule(first)
    }

    @objc private func onTouchUp() {
        stopRepeating()
        // A repeating key already fired on touch down.
        guard !repeatsWhileHeld, let key else { return }
        onKey?(key)
    }

    @objc private func onTouchEnd() {
        stopRepeating()
    }

    private func startRepeating() {
        let timer = Timer(timeInterval: Self.repeatInterval, repeats: true) { [weak self] _ in
            guard let self, let key = self.key else { return }
            self.onKey?(key)
        }
        schedule(timer)
    }

    /// `.common` mode keeps it firing while a scroll view is tracking the touch.
    private func schedule(_ timer: Timer) {
        repeatTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { stopRepeating() }
    }

    // MARK: - Building

    private func applyFill(_ fill: Fill) {
        switch fill {
        case .clear:
            break
        case .box:
            surface.backgroundColor = RemoteTheme.box
        case .linear(let top, let bottom):
            let gradient = RemoteGradientView()
            surface.addSubview(gradient)
            gradient.pinEdges(to: surface)
            gradient.setLinear(top: top, bottom: bottom)
        case .radial(let radial, let opacity):
            let gradient = RemoteGradientView()
            surface.addSubview(gradient)
            gradient.pinEdges(to: surface)
            gradient.setRadial(radial)
            gradient.alpha = opacity
        }
    }

    private func buildContent(icon: Icon?, title: String?, font: UIFont, layout: Layout) {
        let iconView = icon.map(Self.makeIconView)
        let label = title.map { text -> UILabel in
            let label = UILabel()
            label.text = text
            label.font = font
            label.textColor = CommonColor.white.color
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            return label
        }

        switch layout {
        case .centered:
            let stack = makeRow(of: [iconView, label].compactMap { $0 }, axis: .vertical, spacing: 6)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: surface.centerYAnchor)
            ])

        case .iconAbove(let spacing):
            guard let iconView, let label else { return }
            for view in [iconView, label] {
                view.translatesAutoresizingMaskIntoConstraints = false
                surface.addSubview(view)
            }
            NSLayoutConstraint.activate([
                iconView.topAnchor.constraint(equalTo: surface.topAnchor, constant: Self.cardIconTop),
                iconView.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
                label.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
                label.centerYAnchor.constraint(
                    equalTo: iconView.bottomAnchor,
                    constant: spacing + Self.titleCenterOffset
                )
            ])

        case .iconBeside(let spacing, let offsetX):
            let stack = makeRow(of: [iconView, label].compactMap { $0 }, axis: .horizontal, spacing: spacing)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: surface.centerXAnchor, constant: offsetX),
                stack.centerYAnchor.constraint(equalTo: surface.centerYAnchor)
            ])
        }
    }

    private func makeRow(of views: [UIView], axis: NSLayoutConstraint.Axis, spacing: CGFloat) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = axis
        stack.spacing = spacing
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(stack)
        return stack
    }

    // MARK: - Icons

    private static func makeIconView(_ icon: Icon) -> UIView {
        switch icon {
        case .image(let name, let transform):
            let slot = makeSlot(size: iconSlot)
            let imageView = makeImageView(named: name)
            imageView.transform = transform
            slot.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: slot.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: slot.centerYAnchor)
            ])
            return slot

        case .layers(let layers):
            let slot = makeSlot(size: iconSlot)
            for layer in layers {
                let imageView = makeImageView(named: layer.name)
                slot.addSubview(imageView)
                NSLayoutConstraint.activate([
                    imageView.centerXAnchor.constraint(equalTo: slot.leadingAnchor, constant: layer.center.x),
                    imageView.centerYAnchor.constraint(equalTo: slot.topAnchor, constant: layer.center.y)
                ])
            }
            return slot

        case .dot(let top, let bottom):
            let dot = RemoteGradientView()
            dot.setLinear(top: top, bottom: bottom)
            dot.layer.cornerRadius = dotSize / 2
            dot.clipsToBounds = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: dotSize),
                dot.heightAnchor.constraint(equalToConstant: dotSize)
            ])
            return dot
        }
    }

    private static func makeSlot(size: CGFloat) -> UIView {
        let slot = UIView()
        slot.isUserInteractionEnabled = false
        slot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            slot.widthAnchor.constraint(equalToConstant: size),
            slot.heightAnchor.constraint(equalToConstant: size)
        ])
        return slot
    }

    /// Shown at the SVG's own size, so each glyph keeps the exact proportions it has in Figma.
    private static func makeImageView(named name: String) -> UIImageView {
        let imageView = UIImageView(image: UIImage(named: name))
        imageView.tintColor = CommonColor.white.color
        imageView.isUserInteractionEnabled = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }
}
