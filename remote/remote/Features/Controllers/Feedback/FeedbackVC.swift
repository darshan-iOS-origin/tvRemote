import UIKit

/// "Share Your Feedback": pick one or more reasons, write more if you like, and send it by e-mail
/// (`FeedbackMail`). Writing is required only when "Other" is picked. Built in code; open it with
/// `NavigationManager.showFeedback(from:)`.
final class FeedbackVC: UIViewController {

    private let backButton = HapticButton(type: .custom)
    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let chipsView = FeedbackChipsView()
    private let tellUsLabel = UILabel()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = HapticButton(type: .custom)

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
        chipsView.onChange = { [weak self] _ in self?.updateTellUsTitle() }
        updateTellUsTitle()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow),
                                               name: UIResponder.keyboardDidShowNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
    }

    // MARK: - Layout

    private func setupViews() {
        backButton.applyBackArrowStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)

        titleLabel.text = "Feedback"
        titleLabel.font = CommonFont.semibold.font(ofSize: 16)
        titleLabel.textColor = CommonColor.white.color

        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive

        let icon = UIImageView(image: UIImage(named: "feedback"))
        icon.contentMode = .scaleAspectFit

        let heading = UILabel()
        heading.text = "Share Your Feedback"
        heading.font = CommonFont.bold.font(ofSize: 20)
        heading.textColor = CommonColor.white.color
        heading.textAlignment = .center

        let subheading = UILabel()
        subheading.text = "Let us know the issue and we'll improve it"
        subheading.font = CommonFont.medium.font(ofSize: 15)
        subheading.textColor = CommonColor.secondaryGray.color
        subheading.textAlignment = .center
        subheading.numberOfLines = 0

        tellUsLabel.font = CommonFont.semibold.font(ofSize: 14)
        tellUsLabel.textColor = CommonColor.white.color

        textView.backgroundColor = UIColor(hex: 0x10182C)
        textView.layer.cornerRadius = 20
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.font = CommonFont.regular.font(ofSize: 14)
        textView.textColor = CommonColor.white.color
        textView.tintColor = CommonColor.primaryBlue.color
        textView.delegate = self

        placeholderLabel.text = "Share more about your experience..."
        placeholderLabel.font = CommonFont.regular.font(ofSize: 14)
        placeholderLabel.textColor = UIColor(hex: 0x707A91)
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isUserInteractionEnabled = false

        sendButton.setTitle("Send", for: .normal)
        sendButton.setTitleColor(CommonColor.white.color, for: .normal)
        sendButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        sendButton.backgroundColor = UIColor(hex: 0x004BF9)
        sendButton.layer.cornerRadius = 26
        sendButton.addTarget(self, action: #selector(onTap_send), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, heading, subheading, chipsView, tellUsLabel, textView])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.setCustomSpacing(16, after: icon)
        stack.setCustomSpacing(24, after: subheading)
        stack.setCustomSpacing(24, after: chipsView)
        stack.setCustomSpacing(12, after: tellUsLabel)

        [backButton, titleLabel, scrollView, sendButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        [stack, placeholderLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        scrollView.addSubview(stack)
        textView.addSubview(placeholderLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            sendButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            sendButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            // Follows the keyboard: the Send button rises above it, and the scroll view (pinned to the
            // button's top) shrinks to the space that is left, so the text box is never behind the keyboard.
            sendButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -20),
            sendButton.heightAnchor.constraint(equalToConstant: 52),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: sendButton.topAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            icon.heightAnchor.constraint(equalToConstant: 100),
            textView.heightAnchor.constraint(equalToConstant: 150),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 16),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 17),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -17)
        ])
        LottieManager.applyButtonBackground(to: sendButton)
    }

    /// "Other" makes the text required.
    private var isTextRequired: Bool { chipsView.selected.contains(.other) }

    private func updateTellUsTitle() {
        tellUsLabel.text = isTextRequired ? "Tell Us More (Required)" : "Tell Us More (Optional)"
    }

    // MARK: - Actions

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    /// The keyboard is up and the layout has settled: scroll to the end of the content (the text box is the last
    /// item, so it ends up just above the keyboard).
    @objc private func keyboardDidShow() {
        guard textView.isFirstResponder else { return }
        scrollView.layoutIfNeeded()
        let bottom = max(-scrollView.adjustedContentInset.top,
                         scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        scrollView.setContentOffset(CGPoint(x: 0, y: bottom), animated: true)
    }

    @objc private func onTap_send() {
        view.endEditing(true)
        let selected = chipsView.selected
        guard !selected.isEmpty else {
            showSimpleAlert(title: "Feedback", message: "Please pick at least one option.")
            return
        }
        let message = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if selected.contains(.other), message.isEmpty {
            showSimpleAlert(title: "Feedback", message: "Please tell us more, since you chose Other.")
            return
        }
        let reasons = FeedbackOption.allCases.filter { selected.contains($0) }.map(\.rawValue)
        FeedbackMail.send(reasons: reasons, message: message, from: self) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}

extension FeedbackVC: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
}
