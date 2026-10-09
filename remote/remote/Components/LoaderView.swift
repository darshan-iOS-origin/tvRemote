import UIKit

/// A full-screen loading overlay: a dimmed backdrop and a small glass pill with three blue dots that bounce
/// one after the other, and an optional message under them ("Processing purchase…"). It blocks touches while
/// it shows.
///
///     LoaderView.show(message: "Restoring purchases…")
///     // ... later, from any thread
///     LoaderView.hide()
///
/// `show` and `hide` can be called from any thread and may be nested: the overlay stays until every `show`
/// has had its `hide`. With Reduce Motion on, the dots fade in turn instead of bouncing.
final class LoaderView: UIView {

    private static var current: LoaderView?
    private static var requests = 0

    private static let blue = UIColor(hex: 0x004BF9)
    private static let dotSize: CGFloat = 12
    private static let dotSpacing: CGFloat = 10
    private static let bounceHeight: CGFloat = 10
    /// One full bounce cycle, with a rest at the end; each dot starts `stagger` seconds after the one before.
    private static let cycle: CFTimeInterval = 1.1
    private static let stagger: CFTimeInterval = 0.16

    private let pill = UIView()
    /// The blurred, tinted layer inside the pill; it follows the pill's rounded corners.
    private let glass = UIView()
    private let messageLabel = UILabel()
    private var dots: [UIView] = []

    // MARK: - Showing and hiding

    /// Shows the loader over `container`, or over the app's key window. A second call only changes the message.
    static func show(message: String? = nil, in container: UIView? = nil) {
        ThreadManager.onMain {
            requests += 1
            if let current {
                current.setMessage(message)
                return
            }
            guard let host = container ?? keyWindow else {
                requests = max(0, requests - 1)
                return
            }
            let loader = LoaderView(frame: host.bounds)
            loader.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            loader.setMessage(message)
            host.addSubview(loader)
            current = loader
            loader.fadeIn()
        }
    }

    /// Ends one `show`. The overlay goes away when the last one ends.
    static func hide() {
        ThreadManager.onMain {
            requests = max(0, requests - 1)
            guard requests == 0, let loader = current else { return }
            current = nil
            loader.fadeOut { loader.removeFromSuperview() }
        }
    }

    /// Removes the overlay whatever the count (a screen going away mid-purchase).
    static func hideAll() {
        ThreadManager.onMain {
            requests = 0
            guard let loader = current else { return }
            current = nil
            loader.fadeOut { loader.removeFromSuperview() }
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    // MARK: - Building

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        alpha = 0
        isAccessibilityElement = false
        accessibilityViewIsModal = true
        buildPill()
        buildContent()
        // Animations are dropped when the app goes to the background: start them again on return.
        NotificationCenter.default.addObserver(
            self, selector: #selector(startAnimating), name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("LoaderView is built in code")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startAnimating() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A capsule with the dots alone; a softer rounded rectangle once a message makes it taller.
        let radius = min(pill.bounds.height / 2, 28)
        pill.layer.cornerRadius = radius
        glass.layer.cornerRadius = radius
    }

    /// A blurred, darkened glass pill with a hairline border and a soft shadow.
    private func buildPill() {
        pill.backgroundColor = .clear
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.35
        pill.layer.shadowRadius = 20
        pill.layer.shadowOffset = CGSize(width: 0, height: 10)
        pill.isAccessibilityElement = true
        pill.accessibilityTraits = .updatesFrequently
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)

        glass.clipsToBounds = true
        glass.isUserInteractionEnabled = false
        glass.translatesAutoresizingMaskIntoConstraints = false
        pill.insertSubview(glass, at: 0)
        glass.layer.cornerCurve = .continuous
        pill.layer.cornerCurve = .continuous

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(blur)

        let tint = UIView()
        tint.backgroundColor = UIColor(hex: 0x10182C).withAlphaComponent(0.78)
        tint.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(tint)

        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: pill.topAnchor),
            glass.bottomAnchor.constraint(equalTo: pill.bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: pill.trailingAnchor),
            blur.topAnchor.constraint(equalTo: glass.topAnchor),
            blur.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            tint.topAnchor.constraint(equalTo: glass.topAnchor),
            tint.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
            tint.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: glass.trailingAnchor)
        ])
    }

    private func buildContent() {
        dots = (0..<3).map { _ in makeDot() }
        let dotRow = UIStackView(arrangedSubviews: dots)
        dotRow.spacing = Self.dotSpacing
        dotRow.alignment = .center
        // Room above the dots for the bounce, so the dots never touch the pill's edge.
        dotRow.layoutMargins = UIEdgeInsets(top: Self.bounceHeight, left: 0, bottom: 0, right: 0)
        dotRow.isLayoutMarginsRelativeArrangement = true

        messageLabel.font = CommonFont.semibold.font(ofSize: 14)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [dotRow, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        NSLayoutConstraint.activate([
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8),
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -26),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -32)
        ])
    }

    /// A blue dot with a soft blue glow.
    private func makeDot() -> UIView {
        let dot = UIView()
        dot.backgroundColor = Self.blue
        dot.layer.cornerRadius = Self.dotSize / 2
        dot.layer.shadowColor = Self.blue.cgColor
        dot.layer.shadowOpacity = 0.7
        dot.layer.shadowRadius = 6
        dot.layer.shadowOffset = .zero
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: Self.dotSize),
            dot.heightAnchor.constraint(equalToConstant: Self.dotSize)
        ])
        return dot
    }

    private func setMessage(_ message: String?) {
        let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        messageLabel.text = text
        messageLabel.isHidden = text.isEmpty
        pill.accessibilityLabel = text.isEmpty ? "Loading" : text
    }

    // MARK: - Animation

    private func fadeIn() {
        pill.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.alpha = 1
            self.pill.transform = .identity
        }
        UIAccessibility.post(notification: .screenChanged, argument: pill)
    }

    private func fadeOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.pill.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            self.dots.forEach { $0.layer.removeAllAnimations() }
            completion()
        })
    }

    /// Each dot hops up and back, one after the other, then they all rest for a moment. With Reduce Motion the
    /// dots stay in place and fade in turn.
    @objc private func startAnimating() {
        let start = CACurrentMediaTime()
        for (index, dot) in dots.enumerated() {
            dot.layer.removeAllAnimations()
            let delay = Self.stagger * CFTimeInterval(index)
            let animation: CAKeyframeAnimation
            if UIAccessibility.isReduceMotionEnabled {
                animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = [0.35, 1, 0.35, 0.35]
            } else {
                animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
                animation.values = [0, -Self.bounceHeight, 0, 0]
            }
            animation.keyTimes = [0, 0.25, 0.5, 1]
            animation.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn),
                CAMediaTimingFunction(name: .linear)
            ]
            animation.duration = Self.cycle
            animation.repeatCount = .infinity
            animation.beginTime = start + delay
            animation.fillMode = .backwards
            dot.layer.add(animation, forKey: "bounce")
        }
    }
}
