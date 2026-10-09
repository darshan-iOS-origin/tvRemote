import UIKit

/// "Premium Activated!": shown after the free trial button. A full screen with the check mark, a title and
/// a line of thanks. Tap anywhere to close it; `onDone` runs once it has gone away.
final class PremiumActivatedVC: UIViewController {

    var onDone: (() -> Void)?

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()

        // Original size (90x90): no scaling.
        let check = UIImageView(image: UIImage(named: "ic_checkmark"))
        check.contentMode = .center
        check.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Premium Activated!"
        title.font = CommonFont.heavy.font(ofSize: 20)
        title.textColor = CommonColor.white.color
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "You’re now a Premium Member!"
        subtitle.font = CommonFont.medium.font(ofSize: 16)
        subtitle.textColor = CommonColor.secondaryGray.color
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [check, title, subtitle])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.setCustomSpacing(20, after: check)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            check.widthAnchor.constraint(equalToConstant: 90),
            check.heightAnchor.constraint(equalToConstant: 90),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap_close)))
        view.accessibilityViewIsModal = true
    }

    @objc private func onTap_close() {
        dismiss(animated: true) { [onDone] in onDone?() }
    }
}
