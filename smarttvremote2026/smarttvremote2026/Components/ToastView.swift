import UIKit

/// A small message pill that floats above the tab bar and goes away by itself. One at a time: showing a new
/// one replaces the old. It does not take touches, so it never blocks the screen under it.
@MainActor
final class ToastView: UIView {

    private static weak var current: ToastView?
    private static var hideTask: Task<Void, Never>?

    /// Shows `message`. With `showsSpinner` it stays until `hide()` or the next toast (used for "Connecting…");
    /// with `staysUntilHidden` it also stays until `hide()` but has no spinner; otherwise it fades out after
    /// `duration` seconds.
    static func show(_ message: String, showsSpinner: Bool = false, staysUntilHidden: Bool = false, duration: TimeInterval = 2.5) {
        guard let window = keyWindow else { return }
        hide(animated: false)
        let toast = ToastView(message: message, showsSpinner: showsSpinner)
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.alpha = 0
        window.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -DeviceLayout.s(80)),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 24),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -24)
        ])
        current = toast
        UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
        UIAccessibility.post(notification: .announcement, argument: message)
        guard !showsSpinner, !staysUntilHidden else { return }
        hideTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            hide()
        }
    }

    static func hide(animated: Bool = true) {
        hideTask?.cancel()
        hideTask = nil
        guard let toast = current else { return }
        current = nil
        if animated {
            UIView.animate(withDuration: 0.2, animations: { toast.alpha = 0 }, completion: { _ in toast.removeFromSuperview() })
        } else {
            toast.removeFromSuperview()
        }
    }

    private static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    }

    private init(message: String, showsSpinner: Bool) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = UIColor(hex: 0x10182C)
        layer.cornerRadius = 22
        layer.borderWidth = 1
        layer.borderColor = UIColor(hex: 0x202A40).cgColor

        let label = UILabel()
        label.text = message
        label.font = CommonFont.medium.font(ofSize: 14)
        label.textColor = CommonColor.white.color
        label.numberOfLines = 2
        label.textAlignment = .center

        var views: [UIView] = [label]
        if showsSpinner {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = CommonColor.white.color
            spinner.startAnimating()
            views.insert(spinner, at: 0)
        }
        let stack = UIStackView(arrangedSubviews: views)
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
