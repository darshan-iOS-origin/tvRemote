import UIKit

/// "Premium Activated!": a dialog over a dimmed screen, shown after the free trial button. It has the check
/// mark, a thank-you line, the four benefits and a "Start Using Premium" button. `onDone` runs once the
/// dialog has gone away.
final class PremiumActivatedVC: UIViewController {

    var onDone: (() -> Void)?

    private let cardView = UIView()

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupCard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: cardView)
    }

    private func setupCard() {
        cardView.backgroundColor = UIColor(hex: 0x10182C)
        cardView.layer.cornerRadius = 30
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

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
        subtitle.textColor = UIColor(hex: 0x707A91)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let features = UIStackView(arrangedSubviews: [
            makeFeature(icon: "feat_1", text: "Instant TV Connection"),
            makeFeature(icon: "feat_2", text: "Cast All Media to TV"),
            makeFeature(icon: "feat_3", text: "Access All Premium Features"),
            makeFeature(icon: "feat_4", text: "Ad-Free Experience")
        ])
        features.axis = .vertical
        features.spacing = 12

        let start = HapticButton(type: .custom)
        start.setTitle("Start Using Premium", for: .normal)
        start.setTitleColor(CommonColor.white.color, for: .normal)
        start.titleLabel?.font = CommonFont.bold.font(ofSize: 18)
        start.backgroundColor = UIColor(hex: 0x004BF9)
        start.heightAnchor.constraint(equalToConstant: LottieManager.buttonHeight).isActive = true
        start.addTarget(self, action: #selector(onTap_start), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 4

        let stack = UIStackView(arrangedSubviews: [check, textStack, features, start])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        stack.setCustomSpacing(12, after: check)
        stack.setCustomSpacing(24, after: features)
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)

        // The card's width comes only from its two side margins: 16pt from the left and 16pt from the right.
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            check.widthAnchor.constraint(equalToConstant: DeviceLayout.s(90)),
            check.heightAnchor.constraint(equalToConstant: DeviceLayout.s(90)),

            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20)
        ])
        LottieManager.applyButtonBackground(to: start)
    }

    private func makeFeature(icon: String, text: String) -> UIView {
        let image = UIImageView(image: UIImage(named: icon))
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: DeviceLayout.s(36)),
            image.heightAnchor.constraint(equalToConstant: DeviceLayout.s(36))
        ])
        let label = UILabel()
        label.text = text
        label.font = CommonFont.semibold.font(ofSize: 14)
        label.textColor = CommonColor.white.color
        label.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [image, label])
        row.alignment = .center
        row.spacing = 14
        return row
    }

    @objc private func onTap_start() {
        dismiss(animated: true) { [onDone] in onDone?() }
    }
}
