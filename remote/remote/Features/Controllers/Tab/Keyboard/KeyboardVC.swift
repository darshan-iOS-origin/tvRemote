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
    private let headerHeight: CGFloat = TabHeader.height
    private let headerButtonSize: CGFloat = 40
    private let headerButtonSpacing: CGFloat = 15
    /// Largest key, from the Figma frame. Smaller screens shrink the keys to fit.
    private let maxKeySize: CGFloat = DeviceLayout.isPad ? DeviceLayout.padKeypadMaxKeySize : 80
    private let minKeySize: CGFloat = 44
    /// Gap between keys, as a share of the key size (Figma: about 29 pt for an 80 pt key).
    private let gapRatio: CGFloat = 0.3
    private let edgeMargin: CGFloat = 16
    private let padBottomMargin: CGFloat = 40
    private let displaySpacing: CGFloat = 16
    private let displayHeight: CGFloat = DeviceLayout.isPad ? DeviceLayout.padKeypadDisplayHeight : 70
    /// Height the number takes between the header and the pad, kept free when sizing the keys.
    private var minDisplayArea: CGFloat { 2 * displaySpacing + displayHeight }

    // MARK: - Views

    private let displayLabel = UILabel()
    private var headerView: UIView?
    private let padStack = UIStackView()
    /// Width of the pad (three keys and two gaps) and its distance from the bottom edge. Both are set in
    /// `updateKeySize`, because the size depends on the screen and on where the tab bar starts.
    private var padWidth: NSLayoutConstraint!
    private var padBottom: NSLayoutConstraint!
    /// Height of the pad (four keys and three gaps). Without it the stack would stretch its first row.
    private var padHeight: NSLayoutConstraint!
    private var glassButtons: [HapticButton] = []
    /// Every key and spacer of the pad, so they can all be resized together.
    private var slotWidths: [NSLayoutConstraint] = []
    private var digitButtons: [RemoteKeyButton] = []

    private var entered = ""
    private var isShowingError = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        scalePadFonts()
        applyThemeBackground()
        let header = buildHeader()
        headerView = header
        buildPad()
        buildDisplay(below: header)
        glassButtons.forEach { $0.applyGlassStyle() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyThemeBackground()
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
        keyboard.addTarget(self, action: #selector(onTap_keyboard), for: .touchUpInside)
        let history = makeGlassButton(icon: "ic_remote_header_clock")
        history.addTarget(self, action: #selector(onTap_history), for: .touchUpInside)
        let add = RemoteKeyButton(
            icon: .image("ic_remote_header_plus"),
            fill: .linear(top: RemoteTheme.blueTop, bottom: RemoteTheme.blueBottom),
            borderWidth: 0,
            width: headerButtonSize,
            height: headerButtonSize
        )
        add.addTarget(self, action: #selector(onTap_addTV), for: .touchUpInside)

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
        displayLabel.font = CommonFont.bold.font(ofSize: DeviceLayout.isPad ? DeviceLayout.padKeypadDisplayFontSize : 50)
        displayLabel.textColor = CommonColor.white.color
        displayLabel.textAlignment = .center
        displayLabel.text = "0"
        displayLabel.textColor = CommonColor.secondaryGray.color
        displayLabel.adjustsFontSizeToFitWidth = true
        // A long number shrinks to stay on one line instead of being cut off.
        displayLabel.minimumScaleFactor = 0.1
        displayLabel.lineBreakMode = .byClipping
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(displayLabel)

        // 16 pt above (under the header) and 16 pt below (above the pad); the number is centred in between.
        NSLayoutConstraint.activate([
            displayLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: displaySpacing),
            displayLabel.bottomAnchor.constraint(equalTo: padStack.topAnchor, constant: -displaySpacing),
            displayLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: edgeMargin),
            displayLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -edgeMargin),
            displayLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: displayHeight)
        ])
    }

    private func updateDisplay() {
        // An empty field shows a gray 0 as the placeholder.
        displayLabel.text = entered.isEmpty ? "0" : entered
        displayLabel.textColor = entered.isEmpty ? CommonColor.secondaryGray.color : CommonColor.white.color
        displayLabel.accessibilityLabel = entered.isEmpty ? "No number entered" : entered
    }

    // MARK: - Number pad

    private func buildPad() {
        padStack.axis = .vertical
        // Rows fill the pad's width, and each row spreads its three slots evenly across it.
        padStack.alignment = .fill
        padStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(padStack)
        padWidth = padStack.widthAnchor.constraint(equalToConstant: 3 * maxKeySize)
        padHeight = padStack.heightAnchor.constraint(equalToConstant: 4 * maxKeySize)
        padBottom = padStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padBottomMargin)

        let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        for digits in rows {
            addRow(digits.map { makeDigitKey($0) })
        }
        addRow([makeSpacer(), makeDigitKey(0), makeBackspaceKey()])

        NSLayoutConstraint.activate([
            padStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            padWidth,
            padHeight,
            padBottom
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
        padStack.addArrangedSubview(row)
    }

    private func makeSpacer() -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        return spacer
    }

    private func makeKey(title: String?) -> RemoteKeyButton {
        RemoteKeyButton(title: title, font: CommonFont.semibold.font(ofSize: DeviceLayout.isPad ? DeviceLayout.padKeypadKeyFontSize : 26))
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
        let icon = UIImageView(image: IconsHelper.image(systemName: "delete.left", pointSize: DeviceLayout.isPad ? DeviceLayout.padKeypadKeyFontSize : 24))
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
        guard let headerView, view.bounds.width > 0 else { return }
        let bottomInset = bottomObstruction() + padBottomMargin
        let availableHeight = view.bounds.height - bottomInset - headerView.frame.maxY - minDisplayArea
        guard availableHeight > 0 else { return }
        let availableWidth = view.bounds.width - 2 * sideMargin
        let byWidth = availableWidth / (3 + 2 * gapRatio)
        let byHeight = availableHeight / (4 + 3 * gapRatio)
        let size = max(minKeySize, floor(min(maxKeySize, byWidth, byHeight)))
        let gap = (size * gapRatio).rounded()

        if slotWidths.first?.constant != size {
            slotWidths.forEach { $0.constant = size }
        }
        padWidth.constant = 3 * size + 2 * gap
        padHeight.constant = 4 * size + 3 * gap
        padBottom.constant = -bottomInset
        padStack.spacing = gap
    }

    /// How much of the bottom of the screen is covered: the home indicator, or the tab bar when it is
    /// taller (the tab bar floats over the content, so the safe area alone does not include it).
    private func bottomObstruction() -> CGFloat {
        var covered = view.safeAreaInsets.bottom
        if let tabBar = tabBarController?.tabBar, !tabBar.isHidden, tabBar.window != nil {
            let tabTop = view.convert(tabBar.bounds, from: tabBar).minY
            covered = max(covered, view.bounds.height - tabTop)
        }
        return covered
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
            guard let self, ClickLimitManager.shared.allowTap(from: self) else { return }
            self.append(digit)
            await self.deliver { try await AppServices.connection.send(key) }
        }
    }

    @objc private func onTap_backspace() {
        Task { [weak self] in
            guard let device = await AppServices.connection.activeDevice else {
                self?.showConnectionRequired()
                return
            }
            guard let self, ClickLimitManager.shared.allowTap(from: self) else { return }
            self.removeLast()
            guard ConnectionManager.canType(device.platform) else { return }
            await self.deliver { try await AppServices.connection.send(TextCommand.backspace) }
        }
    }

    /// Keyboard in the header: type with the phone's keyboard and send the text to the TV.
    @objc private func onTap_keyboard() {
        TVTextEntry.present(
            from: self,
            onNeedConnection: { [weak self] in self?.showConnectionRequired() },
            onError: { [weak self] in self?.showError($0) }
        )
    }

    /// Clock in the header: the TVs connected before.
    @objc private func onTap_history() {
        NavigationManager.shared.showHistory(from: navigationController)
    }

    /// "+" in the header: open My TVs, where the user connects another TV or scans for a new one.
    @objc private func onTap_addTV() {
        NavigationManager.shared.showMyTVs(from: navigationController)
    }

    private func append(_ digit: Int) {
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
