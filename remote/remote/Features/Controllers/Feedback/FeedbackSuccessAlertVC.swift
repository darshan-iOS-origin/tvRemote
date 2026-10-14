import UIKit

/// "Thank You 🎉" card shown over `FeedbackVC` after the feedback mail was sent. Present it with
/// `FeedbackSuccessAlertVC.present(from:onDone:)`; `onDone` runs after the alert is dismissed.
final class FeedbackSuccessAlertVC: UIViewController {

    private let onDone: () -> Void

    private init(onDone: @escaping () -> Void) {
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    static func present(from presenter: UIViewController, onDone: @escaping () -> Void) {
        presenter.present(FeedbackSuccessAlertVC(onDone: onDone), animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupViews()
    }

    private func setupViews() {
        let card = UIView()
        card.backgroundColor = UIColor(hex: 0x10182C)
        card.layer.cornerRadius = 28
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        let image = UIImageView(image: UIImage(named: "feedback_success"))
        image.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "Thank You 🎉"
        title.font = CommonFont.semibold.font(ofSize: 24)
        title.textColor = CommonColor.white.color
        title.textAlignment = .center

        let message = UILabel()
        message.text = "Your Feedback has been sent successfully."
        message.font = CommonFont.regular.font(ofSize: 18)
        message.textColor = CommonColor.secondaryGray.color
        message.textAlignment = .center
        message.numberOfLines = 0

        let done = HapticButton(type: .custom)
        done.setTitle("Done", for: .normal)
        done.setTitleColor(CommonColor.white.color, for: .normal)
        done.titleLabel?.font = CommonFont.semibold.font(ofSize: 18)
        done.backgroundColor = UIColor(hex: 0x004BF9)
        done.layer.cornerRadius = 22
        done.addTarget(self, action: #selector(onTap_done), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [image, title, message, done])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.setCustomSpacing(12, after: image)
        stack.setCustomSpacing(24, after: message)

        [card, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(card)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            image.heightAnchor.constraint(equalToConstant: DeviceLayout.s(120)),
            done.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44))
        ])
    }

    @objc private func onTap_done() {
        AnalyticsManager.shared.log(FirebaseEvents.Tap.feedbackSentAlertDone)
        dismiss(animated: true) { [onDone] in onDone() }
    }
}
