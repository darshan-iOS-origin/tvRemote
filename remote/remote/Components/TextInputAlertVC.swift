import UIKit

/// A dimmed screen with a card holding a title, a text field, Cancel and a confirm button. It is the
/// Rename dialog, and the box the remote's keyboard button types into. Present it over the current
/// screen; `onSubmit` gets the trimmed, non-empty text.
final class TextInputAlertVC: UIViewController {

    var onSubmit: ((String) -> Void)?

    private let dialogTitle: String
    private let placeholder: String
    private let actionTitle: String
    private let initialName: String
    private let card = UIView()
    private let field = PaddedTextField()
    private let renameButton = HapticButton(type: .custom)
    private var cardCenterY: NSLayoutConstraint?

    init(title: String = "Rename", placeholder: String = "Enter Name",
         actionTitle: String = "Rename", currentName: String = "") {
        dialogTitle = title
        self.placeholder = placeholder
        self.actionTitle = actionTitle
        initialName = currentName
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        dialogTitle = ""
        placeholder = ""
        actionTitle = ""
        initialName = ""
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupViews()
        updateRenameButton()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        field.becomeFirstResponder()
    }

    private func setupViews() {
        card.backgroundColor = UIColor(hex: 0x10182C)
        card.layer.cornerRadius = 24
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(hex: 0x202A40).cgColor

        let title = UILabel()
        title.text = dialogTitle
        title.font = CommonFont.bold.font(ofSize: 18)
        title.textColor = CommonColor.white.color

        field.text = initialName
        field.font = CommonFont.medium.font(ofSize: 14)
        field.textColor = CommonColor.white.color
        field.tintColor = CommonColor.primaryBlue.color
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(hex: 0x707A91)]
        )
        field.backgroundColor = UIColor(hex: 0x1B2438)
        field.layer.cornerRadius = 22
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .done
        field.autocorrectionType = .no
        field.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        field.addTarget(self, action: #selector(onTap_rename), for: .editingDidEndOnExit)

        let cancel = makeButton(title: "Cancel", background: UIColor(hex: 0x1B2438))
        cancel.addTarget(self, action: #selector(onTap_cancel), for: .touchUpInside)
        renameButton.setTitle(actionTitle, for: .normal)
        style(renameButton, background: UIColor(hex: 0x004BF9))
        renameButton.addTarget(self, action: #selector(onTap_rename), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [cancel, renameButton])
        buttons.spacing = 12
        buttons.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [title, field, buttons])
        stack.axis = .vertical
        stack.spacing = 16

        [card, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(card)
        card.addSubview(stack)
        let centerY = card.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        cardCenterY = centerY
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            centerY,
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            field.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44)),
            buttons.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44))
        ])
    }

    private func makeButton(title: String, background: UIColor) -> HapticButton {
        let button = HapticButton(type: .custom)
        button.setTitle(title, for: .normal)
        style(button, background: background)
        return button
    }

    private func style(_ button: HapticButton, background: UIColor) {
        button.backgroundColor = background
        button.layer.cornerRadius = 22
        button.titleLabel?.font = CommonFont.semibold.font(ofSize: 14)
        button.setTitleColor(CommonColor.white.color, for: .normal)
        button.setTitleColor(UIColor(hex: 0x707A91), for: .disabled)
    }

    private var trimmedName: String {
        (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateRenameButton() {
        renameButton.isEnabled = !trimmedName.isEmpty
        renameButton.alpha = renameButton.isEnabled ? 1 : 0.5
    }

    @objc private func textChanged() {
        updateRenameButton()
    }

    @objc private func onTap_cancel() {
        dismiss(animated: true)
    }

    @objc private func onTap_rename() {
        let name = trimmedName
        guard !name.isEmpty else { return }
        dismiss(animated: true) { [onSubmit] in onSubmit?(name) }
    }

    /// Keeps the card above the keyboard.
    @objc private func keyboardChanged(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        cardCenterY?.constant = -overlap / 2
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }
}

/// A text field with 16pt of space on each side, and room on the right for the clear (x) button so the
/// text never runs under it and the button does not touch the rounded edge.
final class PaddedTextField: UITextField {

    private let side: CGFloat = 16
    private let clearSpace: CGFloat = 44

    private var insets: UIEdgeInsets {
        UIEdgeInsets(top: 0, left: side, bottom: 0, right: clearSpace)
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insets)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insets)
    }

    override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.clearButtonRect(forBounds: bounds)
        rect.origin.x = bounds.width - side - rect.width
        return rect
    }
}
