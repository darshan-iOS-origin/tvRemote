import UIKit

/// "Enter Pairing Code" dialog: the TV shows a code and the user types it here.
/// Three looks, as in the design: empty (Pair is off), filled (Pair is on) and wrong code (red, with a note).
final class PairingCodeAlertVC: UIViewController {

    /// Called with the typed code (spaces and dashes removed, upper case) when the user taps Pair.
    var onPair: ((String) -> Void)?
    /// Called after the dialog has gone away because the user backed out.
    var onCancel: (() -> Void)?

    private enum CodeState { case empty, filled, wrong }

    private static let boxColor = UIColor(hex: 0x10182C)
    private static let mutedColor = UIColor(hex: 0x707A91)
    private static let blueColor = UIColor(hex: 0x004BF9)
    private static let redColor = UIColor(hex: 0xD82117)
    private static let letterSpacing: CGFloat = 12

    private let format: PairingCodeFormat
    private var state: CodeState = .empty
    private var isLoading = false

    private let backdropView = UIView()
    private let cardView = UIView()
    private let codeContainer = UIView()
    private let codeField = UITextField()
    private let errorLabel = UILabel()
    private let pairButton = HapticButton(type: .custom)
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(format: PairingCodeFormat) {
        self.format = format
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupBackdrop()
        setupCard()
        applyState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        codeField.becomeFirstResponder()
    }

    // MARK: - Public

    /// Shows a spinner on Pair and stops the code from being edited while the TV is checking it.
    func setLoading(_ loading: Bool) {
        isLoading = loading
        codeField.isUserInteractionEnabled = !loading
        loading ? spinner.startAnimating() : spinner.stopAnimating()
        applyState()
        if !loading, presentedViewController == nil {
            codeField.becomeFirstResponder()
        }
    }

    /// Turns the code red with the "new code" note. Typing again starts a fresh code.
    func showWrongCode() {
        state = .wrong
        applyState()
    }

    func close(completion: (() -> Void)? = nil) {
        view.endEditing(true)
        dismiss(animated: true, completion: completion)
    }

    // MARK: - Layout

    private func setupBackdrop() {
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap_backdrop)))
        view.addSubview(backdropView)
        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupCard() {
        cardView.backgroundColor = Self.boxColor
        cardView.layer.cornerRadius = 30
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        // Header: icon, title, hint.
        let iconView = UIImageView(image: UIImage(named: "scanning") ?? IconsHelper.image(systemName: "tv", pointSize: 56))
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Self.blueColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Enter Pairing Code"
        titleLabel.font = CommonFont.bold.font(ofSize: 20)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .center

        let hintLabel = UILabel()
        hintLabel.text = "Enter the code displayed on your TV Screen"
        hintLabel.font = CommonFont.regular.font(ofSize: 14)
        hintLabel.textColor = Self.mutedColor
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [iconView, titleLabel, hintLabel])
        headerStack.axis = .vertical
        headerStack.alignment = .fill
        headerStack.spacing = 15

        // Code pill and the "incorrect" note.
        setupCodeField()
        errorLabel.text = "Incorrect code. A new code will\nappear on your TV."
        errorLabel.font = CommonFont.regular.font(ofSize: 14)
        errorLabel.textColor = Self.mutedColor
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0

        let inputStack = UIStackView(arrangedSubviews: [codeContainer, errorLabel])
        inputStack.axis = .vertical
        inputStack.alignment = .fill
        inputStack.spacing = 10

        // Pair button.
        pairButton.setTitle("Pair", for: .normal)
        pairButton.setTitleColor(CommonColor.white.color, for: .normal)
        pairButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        pairButton.layer.cornerRadius = 26
        pairButton.addTarget(self, action: #selector(onTap_pair), for: .touchUpInside)
        spinner.color = CommonColor.white.color
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        pairButton.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: pairButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: pairButton.centerYAnchor)
        ])

        let contentStack = UIStackView(arrangedSubviews: [headerStack, inputStack, pairButton])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 25
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        // 353pt wide on a phone (20pt margins), capped on iPad. Centered, but kept above the keyboard.
        let leading = cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        leading.priority = .defaultHigh
        let trailing = cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        trailing.priority = .defaultHigh
        let centerY = cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        centerY.priority = .defaultHigh

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 353),
            leading,
            trailing,
            centerY,
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 30),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -30),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 23),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -23),

            iconView.heightAnchor.constraint(equalToConstant: 100),
            codeContainer.heightAnchor.constraint(equalToConstant: 60),
            pairButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func setupCodeField() {
        codeContainer.layer.cornerRadius = 30
        codeContainer.layer.borderWidth = 1
        codeContainer.clipsToBounds = true

        let attributes = Self.textAttributes(color: CommonColor.white.color)
        codeField.defaultTextAttributes = attributes
        codeField.attributedPlaceholder = NSAttributedString(
            string: String(repeating: "X", count: format.lengths.upperBound),
            attributes: Self.textAttributes(color: Self.mutedColor)
        )
        codeField.textAlignment = .center
        codeField.tintColor = Self.blueColor
        codeField.keyboardType = format.characters == .digits ? .numberPad : .asciiCapable
        codeField.autocorrectionType = .no
        codeField.autocapitalizationType = .allCharacters
        codeField.spellCheckingType = .no
        codeField.textContentType = .oneTimeCode
        codeField.delegate = self
        // The last letter's spacing leans the text left. This empty view on the left balances it.
        codeField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Self.letterSpacing, height: 1))
        codeField.leftViewMode = .always
        codeField.translatesAutoresizingMaskIntoConstraints = false
        codeContainer.addSubview(codeField)
        NSLayoutConstraint.activate([
            codeField.topAnchor.constraint(equalTo: codeContainer.topAnchor),
            codeField.bottomAnchor.constraint(equalTo: codeContainer.bottomAnchor),
            codeField.leadingAnchor.constraint(equalTo: codeContainer.leadingAnchor, constant: 12),
            codeField.trailingAnchor.constraint(equalTo: codeContainer.trailingAnchor, constant: -12)
        ])
    }

    private static func textAttributes(color: UIColor) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return [
            .font: CommonFont.semibold.font(ofSize: 26),
            .foregroundColor: color,
            .kern: letterSpacing,
            .paragraphStyle: style
        ]
    }

    // MARK: - State

    private var typedCode: String {
        format.normalized(codeField.text ?? "")
    }

    private func applyState() {
        let hasCode = !typedCode.isEmpty
        if state != .wrong {
            state = hasCode ? .filled : .empty
        }

        let color: UIColor
        switch state {
        case .empty: color = Self.mutedColor
        case .filled: color = CommonColor.white.color
        case .wrong: color = Self.redColor
        }
        let borderColor: UIColor
        switch state {
        case .empty: borderColor = Self.mutedColor
        case .filled: borderColor = Self.blueColor
        case .wrong: borderColor = Self.redColor
        }
        codeField.defaultTextAttributes = Self.textAttributes(color: color)
        // Re-apply so the text already typed picks up the new color.
        if let text = codeField.text, !text.isEmpty { codeField.text = text }
        codeContainer.layer.borderColor = borderColor.cgColor
        errorLabel.isHidden = state != .wrong

        let isComplete = format.isValid(typedCode)
        let canPair = isComplete && !isLoading
        pairButton.backgroundColor = (isComplete || isLoading) ? Self.blueColor : Self.mutedColor
        pairButton.setTitleColor(isLoading ? .clear : CommonColor.white.color, for: .normal)
        pairButton.isUserInteractionEnabled = canPair
    }

    // MARK: - Actions

    @objc private func onTap_pair() {
        let code = typedCode
        guard format.isValid(code), !isLoading else { return }
        onPair?(code)
    }

    @objc private func onTap_backdrop() {
        if codeField.isFirstResponder {
            codeField.resignFirstResponder()
        } else if !isLoading {
            close { [onCancel] in onCancel?() }
        }
    }
}

// MARK: - UITextFieldDelegate

extension PairingCodeAlertVC: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        guard let textRange = Range(range, in: current) else { return false }

        // After a wrong code, the first character typed starts a new code. Backspace edits as usual.
        let restarts = state == .wrong && !string.isEmpty
        let updated = format.normalized(restarts ? string : current.replacingCharacters(in: textRange, with: string))

        guard updated.allSatisfy({ format.characters.allows($0) }),
              updated.count <= format.lengths.upperBound else { return false }

        state = .empty
        textField.text = updated
        applyState()
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onTap_pair()
        return false
    }
}
