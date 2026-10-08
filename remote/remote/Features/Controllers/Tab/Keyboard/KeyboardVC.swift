//
//  KeyboardVC.swift
//  remote
//
//  The Keyboard tab: a number pad. Each digit is sent to the TV as soon as it is tapped and also shown
//  in the big display. Backspace removes the last digit and, on TVs that can type, sends a backspace.
//

import UIKit

class KeyboardVC: UIViewController {

    // MARK: - Metrics

    private let sideMargin: CGFloat = 20
    private let headerHeight: CGFloat = 60
    private let headerButtonSize: CGFloat = 40
    private let headerButtonSpacing: CGFloat = 15
    /// Largest key, from the Figma frame. Smaller screens shrink the keys to fit.
    private let maxKeySize: CGFloat = 80
    private let minKeySize: CGFloat = 44
    /// Gap between keys, as a share of the key size (Figma: about 29 pt for an 80 pt key).
    private let gapRatio: CGFloat = 0.3
    /// Longest number the display holds, the same limit as `ChannelNumber`.
    private let maxDigits = 8

    // MARK: - Views

    private let displayLabel = UILabel()
    private let padContainer = UIView()
    private let padStack = UIStackView()
    private var glassButtons: [HapticButton] = []
    /// Every key and spacer of the pad, so they can all be resized together.
    private var slotWidths: [NSLayoutConstraint] = []
    private var rowStacks: [UIStackView] = []
    private var digitButtons: [RemoteKeyButton] = []

    private var entered = ""
    private var isShowingError = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        let header = buildHeader()
        buildDisplay(below: header)
        buildPad()
        glassButtons.forEach { $0.applyGlassStyle() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        entered = ""
        updateDisplay()
        refreshAvailableKeys()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        glassButtons.forEach { $0.updateGlassFallbackCorners() }
        updateKeySize()
    }

    // MARK: - Header (the same look as the Remote tab; the buttons do nothing yet)

    private func buildHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let title = UILabel()
        title.attributedText = makeTitle()
        title.setContentHuggingPriority(.required, for: .horizontal)

        let keyboard = makeGlassButton(icon: "ic_remote_header_keyboard")
        let history = makeGlassButton(icon: "ic_remote_header_clock")
        let add = RemoteKeyButton(
            icon: .image("ic_remote_header_plus"),
            fill: .linear(top: RemoteTheme.blueTop, bottom: RemoteTheme.blueBottom),
            borderWidth: 0,
            width: headerButtonSize,
            height: headerButtonSize
        )

        let actions = UIStackView(arrangedSubviews: [keyboard, history, add])
        actions.spacing = headerButtonSpacing
        actions.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [title, UIView(), actions])
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(row)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: headerHeight),
            row.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: sideMargin),
            row.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -sideMargin),
            row.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        return header
    }

    /// "TV" in the brand blue followed by " Remote" in white.
    private func makeTitle() -> NSAttributedString {
        let font = CommonFont.heavy.font(ofSize: 24)
        let title = NSMutableAttributedString(string: "TV", attributes: [
            .font: font,
            .foregroundColor: CommonColor.primaryBlue.color,
            .kern: 0.24
        ])
        title.append(NSAttributedString(string: " Remote", attributes: [
            .font: font,
            .foregroundColor: CommonColor.white.color,
            .kern: 0.24
        ]))
        return title
    }

    private func makeGlassButton(icon: String) -> HapticButton {
        let button = HapticButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: icon), for: .normal)
        button.tintColor = CommonColor.white.color
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: headerButtonSize),
            button.heightAnchor.constraint(equalToConstant: headerButtonSize)
        ])
        glassButtons.append(button)
        return button
    }

    // MARK: - Display

    private func buildDisplay(below header: UIView) {
        displayLabel.font = CommonFont.bold.font(ofSize: 50)
        displayLabel.textColor = CommonColor.white.color
        displayLabel.textAlignment = .center
        displayLabel.adjustsFontSizeToFitWidth = true
        displayLabel.minimumScaleFactor = 0.5
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(displayLabel)

        NSLayoutConstraint.activate([
            displayLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            displayLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
            displayLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
            // Fixed height, so the pad does not jump when the number is empty.
            displayLabel.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    private func updateDisplay() {
        displayLabel.text = entered
        displayLabel.accessibilityLabel = entered.isEmpty ? "No number entered" : entered
    }

    // MARK: - Number pad

    private func buildPad() {
        padContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(padContainer)

        padStack.axis = .vertical
        padStack.alignment = .center
        padStack.translatesAutoresizingMaskIntoConstraints = false
        padContainer.addSubview(padStack)

        let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        for digits in rows {
            addRow(digits.map { makeDigitKey($0) })
        }
        addRow([makeSpacer(), makeDigitKey(0), makeBackspaceKey()])

        NSLayoutConstraint.activate([
            padContainer.topAnchor.constraint(equalTo: displayLabel.bottomAnchor),
            padContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            padContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            padContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            padStack.centerXAnchor.constraint(equalTo: padContainer.centerXAnchor),
            padStack.centerYAnchor.constraint(equalTo: padContainer.centerYAnchor)
        ])
    }

    private func addRow(_ slots: [UIView]) {
        let row = UIStackView(arrangedSubviews: slots)
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        for slot in slots {
            let width = slot.widthAnchor.constraint(equalToConstant: maxKeySize)
            width.isActive = true
            slotWidths.append(width)
            slot.heightAnchor.constraint(equalTo: slot.widthAnchor).isActive = true
        }
        rowStacks.append(row)
        padStack.addArrangedSubview(row)
    }

    private func makeSpacer() -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        return spacer
    }

    private func makeKey(title: String?) -> RemoteKeyButton {
        RemoteKeyButton(title: title, font: CommonFont.semibold.font(ofSize: 26))
    }

    private func makeDigitKey(_ digit: Int) -> RemoteKeyButton {
        let button = makeKey(title: String(digit))
        let key = Self.digitKeys[digit]
        button.bind(key) { [weak self] in self?.press($0) }
        button.accessibilityLabel = String(digit)
        digitButtons.append(button)
        return button
    }

    private func makeBackspaceKey() -> RemoteKeyButton {
        let button = makeKey(title: nil)
        let icon = UIImageView(image: IconsHelper.image(systemName: "delete.left", pointSize: 24))
        icon.tintColor = CommonColor.white.color
        icon.contentMode = .scaleAspectFit
        icon.isUserInteractionEnabled = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        button.addTarget(self, action: #selector(onTap_backspace), for: .touchUpInside)
        button.accessibilityLabel = "Delete"
        return button
    }

    /// One key size for the whole pad: the Figma 80 pt, or smaller when the width or the height of the
    /// space between the number and the tab bar is short (a small iPhone, or a large text size).
    private func updateKeySize() {
        let space = padContainer.bounds
        guard space.width > 0, space.height > 0 else { return }
        let availableWidth = space.width - 2 * sideMargin
        let availableHeight = space.height - 24
        let byWidth = availableWidth / (3 + 2 * gapRatio)
        let byHeight = availableHeight / (4 + 3 * gapRatio)
        let size = max(minKeySize, floor(min(maxKeySize, byWidth, byHeight)))
        let gap = (size * gapRatio).rounded()

        if slotWidths.first?.constant != size {
            slotWidths.forEach { $0.constant = size }
        }
        padStack.spacing = gap
        rowStacks.forEach { $0.spacing = gap }
    }

    // MARK: - Keys

    private static let digitKeys: [KeyCommand] = [
        .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9
    ]

    private func press(_ key: KeyCommand) {
        guard let digit = key.digitValue else { return }
        Task { [weak self] in
            guard await AppServices.connection.activeDevice != nil else {
                self?.showConnectionRequired()
                return
            }
            self?.append(digit)
            await self?.deliver { try await AppServices.connection.send(key) }
        }
    }

    @objc private func onTap_backspace() {
        Task { [weak self] in
            guard let device = await AppServices.connection.activeDevice else {
                self?.showConnectionRequired()
                return
            }
            self?.removeLast()
            guard ConnectionManager.canType(device.platform) else { return }
            await self?.deliver { try await AppServices.connection.send(TextCommand.backspace) }
        }
    }

    private func append(_ digit: Int) {
        guard entered.count < maxDigits else { return }
        entered.append(String(digit))
        updateDisplay()
    }

    private func removeLast() {
        guard !entered.isEmpty else { return }
        entered.removeLast()
        updateDisplay()
    }

    private func deliver(_ send: () async throws -> Void) async {
        do {
            try await send()
        } catch let error as TVError {
            LoggerManager.warning("Sending a keypad key failed: \(error)", category: "Keyboard")
            showError(error.userMessage)
        } catch {
            showError(TVError.unreachable.userMessage)
        }
    }

    /// Dims the digits the connected TV does not have. With no TV, or one we know nothing about, every key stays on.
    private func refreshAvailableKeys() {
        Task { [weak self] in
            let platform = await AppServices.connection.activeDevice?.platform
            guard let self else { return }
            for button in self.digitButtons {
                guard let key = button.key, let platform else {
                    button.setAvailable(true)
                    continue
                }
                button.setAvailable(ConnectionManager.supports(key, on: platform))
            }
        }
    }

    // MARK: - Alerts

    private func showError(_ message: String) {
        guard !isShowingError, presentedViewController == nil, tabBarController?.presentedViewController == nil else { return }
        isShowingError = true
        showSimpleAlert(title: "Keyboard", message: message) { [weak self] in self?.isShowingError = false }
    }

    /// Asks the user to connect a TV. Presented from the tab bar controller so the dim covers the tab bar too.
    private func showConnectionRequired() {
        let host = tabBarController ?? self
        guard host.presentedViewController == nil else { return }
        let alert = ConnectionRequiredAlertVC()
        alert.onConnect = { [weak self] in
            NavigationManager.shared.showScanning(from: self?.navigationController)
        }
        host.present(alert, animated: true)
    }
}
