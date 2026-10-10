import UIKit

/// A full-screen loading overlay in the familiar iOS style: a lightly dimmed backdrop and a small dark rounded
/// square with the system activity indicator and an optional message under it ("Processing purchase…"). It
/// blocks touches while it shows.
///
///     LoaderView.show(message: "Restoring purchases…")
///     // ... later, from any thread
///     LoaderView.hide()
///
/// `show` and `hide` can be called from any thread and may be nested: the overlay stays until every `show`
/// has had its `hide`.
final class LoaderView: UIView {

    private static var current: LoaderView?
    private static var requests = 0

    private let box = UIView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()

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
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        alpha = 0
        isAccessibilityElement = false
        accessibilityViewIsModal = true
        buildBox()
    }

    required init?(coder: NSCoder) {
        fatalError("LoaderView is built in code")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // The system indicator spins again when it is on screen; this also covers a return from the background.
        if window != nil { spinner.startAnimating() }
    }

    /// A dark rounded square, at least 120 pt each way, with the spinner and the message centered in it.
    private func buildBox() {
        box.backgroundColor = UIColor(hex: 0x10182C).withAlphaComponent(0.96)
        box.layer.cornerRadius = 20
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = UIColor(hex: 0x202A40).cgColor
        box.isAccessibilityElement = true
        box.accessibilityTraits = .updatesFrequently
        box.translatesAutoresizingMaskIntoConstraints = false
        addSubview(box)

        spinner.color = .white
        spinner.hidesWhenStopped = false

        messageLabel.font = CommonFont.medium.font(ofSize: 14)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [spinner, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)

        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: centerXAnchor),
            box.centerYAnchor.constraint(equalTo: centerYAnchor),
            box.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            box.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            box.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.75),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -20)
        ])
    }

    private func setMessage(_ message: String?) {
        let text = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        messageLabel.text = text
        messageLabel.isHidden = text.isEmpty
        box.accessibilityLabel = text.isEmpty ? "Loading" : text
    }

    // MARK: - Animation

    private func fadeIn() {
        spinner.startAnimating()
        box.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.box.transform = .identity
        }
        UIAccessibility.post(notification: .screenChanged, argument: box)
    }

    private func fadeOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.15, animations: {
            self.alpha = 0
            self.box.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            self.spinner.stopAnimating()
            completion()
        })
    }
}
