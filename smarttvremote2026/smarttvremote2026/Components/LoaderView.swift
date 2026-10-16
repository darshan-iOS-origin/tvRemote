import UIKit

/// A full-screen loading overlay in the app's dialog style: the screen dims like behind the other dialogs, and
/// a dark card shows a spinner with the brand's cyan-to-blue gradient over a soft blue glow, the message
/// ("Processing purchase…") and a quiet line under it.
///
///     LoaderView.show(message: "Restoring purchases…")
///     // ... later, from any thread
///     LoaderView.hide()
///
/// `show` and `hide` can be called from any thread and may be nested: the overlay stays until every `show`
/// has had its `hide`. It blocks touches while it shows. With Reduce Motion on, the spinner pulses instead of
/// turning.
final class LoaderView: UIView {

    private static var current: LoaderView?
    private static var requests = 0

    // The same colors as the dialogs and the "Your Premium" title.
    private static let cardColor = UIColor(hex: 0x10182C)
    private static let borderColor = UIColor(hex: 0x202A40)
    private static let mutedColor = UIColor(hex: 0x707A91)
    private static let cyan = UIColor(hex: 0x00CFFE)
    private static let blue = UIColor(hex: 0x004BF9)

    private static let ringSize: CGFloat = 52
    private static let ringWidth: CGFloat = 4.5

    private let card = UIView()
    private let ringHolder = UIView()
    private let glow = UIView()
    private let track = CAShapeLayer()
    private let arc = CAShapeLayer()
    private let gradient = CAGradientLayer()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

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
        buildCard()
        buildSpinner()
        buildTexts()
        // Animations are dropped while the app is in the background: start them again on return.
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

    /// The dark card, like the app's dialogs: rounded, with a hairline border and a deep shadow.
    private func buildCard() {
        card.backgroundColor = Self.cardColor
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = Self.borderColor.cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.45
        card.layer.shadowRadius = 30
        card.layer.shadowOffset = CGSize(width: 0, height: 16)
        card.isAccessibilityElement = true
        card.accessibilityTraits = .updatesFrequently
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
    }

    /// A faint track, and an arc with the cyan-to-blue gradient that grows, shrinks and turns, over a soft blue
    /// glow.
    private func buildSpinner() {
        let size = Self.ringSize
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        let path = UIBezierPath(
            arcCenter: CGPoint(x: size / 2, y: size / 2),
            radius: (size - Self.ringWidth) / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )

        glow.backgroundColor = Self.blue.withAlphaComponent(0.22)
        glow.layer.shadowColor = Self.blue.cgColor
        glow.layer.shadowOpacity = 0.9
        glow.layer.shadowRadius = 18
        glow.layer.shadowOffset = .zero
        glow.translatesAutoresizingMaskIntoConstraints = false
        ringHolder.addSubview(glow)

        track.path = path.cgPath
        track.fillColor = UIColor.clear.cgColor
        track.strokeColor = Self.borderColor.cgColor
        track.lineWidth = Self.ringWidth
        track.frame = bounds
        ringHolder.layer.addSublayer(track)

        gradient.colors = [Self.cyan.cgColor, Self.blue.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = bounds
        arc.path = path.cgPath
        arc.fillColor = UIColor.clear.cgColor
        arc.strokeColor = UIColor.black.cgColor
        arc.lineWidth = Self.ringWidth
        arc.lineCap = .round
        arc.strokeStart = 0
        arc.strokeEnd = 0.3
        arc.frame = bounds
        gradient.mask = arc
        ringHolder.layer.addSublayer(gradient)

        ringHolder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ringHolder.widthAnchor.constraint(equalToConstant: size),
            ringHolder.heightAnchor.constraint(equalToConstant: size),
            glow.centerXAnchor.constraint(equalTo: ringHolder.centerXAnchor),
            glow.centerYAnchor.constraint(equalTo: ringHolder.centerYAnchor),
            glow.widthAnchor.constraint(equalToConstant: size * 0.7),
            glow.heightAnchor.constraint(equalToConstant: size * 0.7)
        ])
        glow.layer.cornerRadius = size * 0.35
    }

    private func buildTexts() {
        titleLabel.font = CommonFont.semibold.font(ofSize: 16)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        detailLabel.text = "This will only take a moment."
        detailLabel.font = CommonFont.regular.font(ofSize: 13)
        detailLabel.textColor = Self.mutedColor
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [ringHolder, titleLabel, detailLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.setCustomSpacing(22, after: ringHolder)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            card.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.78),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 30),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -26),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28)
        ])
    }

    /// The message is the title; with none, "Please wait".
    private func setMessage(_ message: String?) {
        let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        titleLabel.text = text.isEmpty ? "Please wait" : text
        card.accessibilityLabel = "\(titleLabel.text ?? ""). \(detailLabel.text ?? "")"
    }

    // MARK: - Animation

    private func fadeIn() {
        card.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0) {
            self.alpha = 1
            self.card.transform = .identity
        }
        UIAccessibility.post(notification: .screenChanged, argument: card)
    }

    private func fadeOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn, animations: {
            self.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }, completion: { _ in
            self.stopAnimating()
            completion()
        })
    }

    /// The arc grows to most of the circle and shrinks again while the whole spinner turns, and the glow breathes.
    /// With Reduce Motion the arc stays still and the spinner pulses instead.
    @objc private func startAnimating() {
        stopAnimating()

        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 0.9
        breathe.toValue = 1.15
        breathe.duration = 1.2
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glow.layer.add(breathe, forKey: "breathe")

        if UIAccessibility.isReduceMotionEnabled {
            arc.strokeStart = 0
            arc.strokeEnd = 0.75
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1
            pulse.toValue = 0.4
            pulse.duration = 0.9
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            gradient.add(pulse, forKey: "pulse")
            return
        }

        // The spin is faster than the arc shrinks, so the head always moves forward and nothing jumps.
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi * 2
        spin.duration = 1.1
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        ringHolder.layer.add(spin, forKey: "spin")

        let stretch = CABasicAnimation(keyPath: "strokeEnd")
        stretch.fromValue = 0.15
        stretch.toValue = 0.75
        stretch.duration = 1.0
        stretch.autoreverses = true
        stretch.repeatCount = .infinity
        stretch.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        arc.add(stretch, forKey: "stretch")
    }

    private func stopAnimating() {
        ringHolder.layer.removeAllAnimations()
        glow.layer.removeAllAnimations()
        arc.removeAllAnimations()
        gradient.removeAllAnimations()
    }
}
