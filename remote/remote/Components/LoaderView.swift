import UIKit

/// A full-screen loading overlay: a dimmed backdrop with a thin ring spinner (a blue tail fading into a white
/// head) and an optional message under it ("Processing purchase…"). There is no box around it. It blocks touches
/// while it shows.
///
///     LoaderView.show(message: "Restoring purchases…")
///     // ... later, from any thread
///     LoaderView.hide()
///
/// `show` and `hide` can be called from any thread and may be nested: the overlay stays until every `show`
/// has had its `hide`. With Reduce Motion on, the ring pulses instead of spinning.
final class LoaderView: UIView {

    private static var current: LoaderView?
    private static var requests = 0

    private static let blue = UIColor(hex: 0x004BF9)
    private static let ringSize: CGFloat = 56
    private static let ringWidth: CGFloat = 3.5

    private let ring = UIView()
    private let messageLabel = UILabel()
    private let track = CAShapeLayer()
    private let gradient = CAGradientLayer()
    private let arc = CAShapeLayer()

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
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        alpha = 0
        isAccessibilityElement = false
        accessibilityViewIsModal = true
        buildRing()
        buildLayout()
        // Animations are dropped when the app goes to the background: start them again on return.
        NotificationCenter.default.addObserver(
            self, selector: #selector(startSpinning), name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("LoaderView is built in code")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startSpinning() }
    }

    /// A faint full ring (the track) under a round-capped arc. The arc is a conic gradient, clear at the tail,
    /// blue in the middle and white at the head, so the spinner looks like it leaves a trail.
    private func buildRing() {
        let size = Self.ringSize
        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        let path = UIBezierPath(
            arcCenter: CGPoint(x: size / 2, y: size / 2),
            radius: (size - Self.ringWidth) / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )

        track.path = path.cgPath
        track.fillColor = UIColor.clear.cgColor
        track.strokeColor = UIColor.white.withAlphaComponent(0.15).cgColor
        track.lineWidth = Self.ringWidth
        track.frame = frame
        ring.layer.addSublayer(track)

        gradient.type = .conic
        gradient.colors = [Self.blue.withAlphaComponent(0).cgColor, Self.blue.cgColor, UIColor.white.cgColor]
        gradient.locations = [0, 0.75, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.frame = frame
        arc.path = path.cgPath
        arc.fillColor = UIColor.clear.cgColor
        arc.strokeColor = UIColor.black.cgColor
        arc.lineWidth = Self.ringWidth
        arc.lineCap = .round
        arc.strokeStart = 0.02
        arc.strokeEnd = 0.98
        arc.frame = frame
        gradient.mask = arc
        ring.layer.addSublayer(gradient)

        ring.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ring.widthAnchor.constraint(equalToConstant: size),
            ring.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func buildLayout() {
        messageLabel.font = CommonFont.medium.font(ofSize: 15)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        // A little shadow keeps the text readable over a bright screen behind the dim.
        messageLabel.layer.shadowColor = UIColor.black.cgColor
        messageLabel.layer.shadowOpacity = 0.5
        messageLabel.layer.shadowRadius = 4
        messageLabel.layer.shadowOffset = CGSize(width: 0, height: 1)

        let stack = UIStackView(arrangedSubviews: [ring, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
        stack.isAccessibilityElement = true
        stack.accessibilityTraits = .updatesFrequently
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        contentStack = stack

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8)
        ])
    }

    private var contentStack: UIStackView?

    private func setMessage(_ message: String?) {
        let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        messageLabel.text = text
        messageLabel.isHidden = text.isEmpty
        contentStack?.accessibilityLabel = text.isEmpty ? "Loading" : text
    }

    // MARK: - Animation

    private func fadeIn() {
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
        UIAccessibility.post(notification: .screenChanged, argument: contentStack)
    }

    private func fadeOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }, completion: { _ in
            self.ring.layer.removeAllAnimations()
            completion()
        })
    }

    @objc private func startSpinning() {
        ring.layer.removeAllAnimations()
        if UIAccessibility.isReduceMotionEnabled {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1
            pulse.toValue = 0.35
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            ring.layer.add(pulse, forKey: "pulse")
        } else {
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = Double.pi * 2
            spin.duration = 0.85
            spin.timingFunction = CAMediaTimingFunction(name: .linear)
            spin.repeatCount = .infinity
            spin.isRemovedOnCompletion = false
            ring.layer.add(spin, forKey: "spin")
        }
    }
}
