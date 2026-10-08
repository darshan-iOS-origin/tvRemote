import UIKit

/// The "Buttons / Touchpad" switch. On iOS 26 and later it is the system segmented control, which draws
/// itself in Liquid Glass. Before that it is a custom glass capsule with a lighter capsule under the
/// selected title.
final class RemoteSegmentedControl: UIView {

    static let height: CGFloat = 50
    private static let inset: CGFloat = 5

    private let titles: [String]
    private let surface = UIView()
    private let indicator = UIView()
    private var systemControl: UISegmentedControl?
    private(set) var selectedIndex = 0

    /// Called after the user picks a segment.
    var onChange: ((Int) -> Void)?

    init(titles: [String]) {
        self.titles = titles
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true
        if #available(iOS 26.0, *) {
            buildSystemControl()
        } else {
            buildSurface()
            buildIndicator()
            buildButtons()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("RemoteSegmentedControl is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard systemControl == nil else { return }
        surface.layer.cornerRadius = bounds.height / 2
        indicator.frame = indicatorFrame(for: selectedIndex)
        indicator.layer.cornerRadius = indicator.bounds.height / 2
    }

    func select(_ index: Int, animated: Bool) {
        guard index != selectedIndex, titles.indices.contains(index) else { return }
        selectedIndex = index
        if let systemControl {
            systemControl.selectedSegmentIndex = index
            return
        }
        let move = { self.indicator.frame = self.indicatorFrame(for: index) }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: move)
        } else {
            move()
        }
    }

    // MARK: - System control (iOS 26+)

    private func buildSystemControl() {
        let control = UISegmentedControl(items: titles)
        control.selectedSegmentIndex = selectedIndex
        let font = CommonFont.semibold.font(ofSize: 15)
        let white = CommonColor.white.color
        control.setTitleTextAttributes([.font: font, .foregroundColor: white], for: .normal)
        control.setTitleTextAttributes([.font: font, .foregroundColor: white], for: .selected)
        control.addTarget(self, action: #selector(onChange_system(_:)), for: .valueChanged)
        addSubview(control)
        control.pinEdges(to: self)
        systemControl = control
    }

    @objc private func onChange_system(_ sender: UISegmentedControl) {
        selectedIndex = sender.selectedSegmentIndex
        HapticManager.trigger(.light)
        onChange?(selectedIndex)
    }

    // MARK: - Custom control (before iOS 26)

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
        guard sender.tag != selectedIndex else { return }
        select(sender.tag, animated: true)
        onChange?(sender.tag)
    }
}
