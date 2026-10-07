import UIKit

/// The "Buttons / Touchpad" switch: a glass capsule with a lighter capsule under the selected title.
/// Visual only for now, nothing else reacts to the selection.
final class RemoteSegmentedControl: UIView {

    static let height: CGFloat = 50
    private static let inset: CGFloat = 5

    private let titles: [String]
    private let surface = UIView()
    private let indicator = UIView()
    private(set) var selectedIndex = 0

    init(titles: [String]) {
        self.titles = titles
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true
        buildSurface()
        buildIndicator()
        buildButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("RemoteSegmentedControl is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.layer.cornerRadius = bounds.height / 2
        indicator.frame = indicatorFrame(for: selectedIndex)
        indicator.layer.cornerRadius = indicator.bounds.height / 2
    }

    func select(_ index: Int, animated: Bool) {
        guard index != selectedIndex, titles.indices.contains(index) else { return }
        selectedIndex = index
        let move = { self.indicator.frame = self.indicatorFrame(for: index) }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: move)
        } else {
            move()
        }
    }

    // MARK: - Building

    /// Blurred, darkened and outlined, like the glass bars in the design.
    private func buildSurface() {
        surface.isUserInteractionEnabled = false
        surface.clipsToBounds = true
        surface.layer.borderWidth = 1
        surface.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        addSubview(surface)
        surface.pinEdges(to: self)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.isUserInteractionEnabled = false
        surface.addSubview(blur)
        blur.pinEdges(to: surface)

        let darken = UIView()
        darken.isUserInteractionEnabled = false
        darken.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        surface.addSubview(darken)
        darken.pinEdges(to: surface)
    }

    private func buildIndicator() {
        indicator.isUserInteractionEnabled = false
        indicator.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        addSubview(indicator)
    }

    private func buildButtons() {
        let buttons = titles.enumerated().map { index, title -> HapticButton in
            let button = HapticButton(frame: .zero)
            button.tag = index
            button.setTitle(title, for: .normal)
            button.setTitleColor(CommonColor.white.color, for: .normal)
            button.titleLabel?.font = CommonFont.semibold.font(ofSize: 15)
            button.addTarget(self, action: #selector(onTap_segment(_:)), for: .touchUpInside)
            return button
        }
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.distribution = .fillEqually
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let inset = Self.inset
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset)
        ])
    }

    private func indicatorFrame(for index: Int) -> CGRect {
        let inset = Self.inset
        let segmentWidth = (bounds.width - inset * 2) / CGFloat(max(titles.count, 1))
        return CGRect(
            x: inset + segmentWidth * CGFloat(index),
            y: inset,
            width: segmentWidth,
            height: bounds.height - inset * 2
        )
    }

    @objc private func onTap_segment(_ sender: UIButton) {
        select(sender.tag, animated: true)
    }
}
