import UIKit

/// Everything that happens between tapping a TV in the list and landing on the remote: asking the TV to
/// pair, the code dialog (with a retry when the code is wrong), and connecting. Brand details stay in
/// `PairingManager` and `ConnectionManager`.
@MainActor
final class TVConnector {

    private weak var presenter: UIViewController?
    private var isBusy = false
    private var hud: ConnectingHUD?

    /// The pairing request the code dialog is answering. It changes when a wrong code makes the TV show a new one.
    private var challenge: PairingChallenge?
    private weak var codeDialog: PairingCodeAlertVC?

    init(presenter: UIViewController) {
        self.presenter = presenter
    }

    func connect(to device: TVDevice) {
        guard !isBusy else { return }
        isBusy = true
        LoggerManager.info("Connecting to \(device.name) (\(device.host)), platform \(device.platform.displayName)", category: "Connect")

        Task {
            switch AppServices.pairing.kind(for: device) {
            case .none:
                await connectDirectly(device, message: "Connecting…")
            case .approveOnTV:
                await connectDirectly(device, message: "Connecting…\nAccept the request on your TV.")
            case .code:
                await startPairing(device)
            case .unavailable:
                finish(withError: "We can't tell how to pair this TV yet.")
            }
        }
    }

    // MARK: - TVs that need no code

    private func connectDirectly(_ device: TVDevice, message: String) async {
        showHUD(message)
        do {
            try await AppServices.connection.connect(to: device)
            hideHUD()
            finishConnected()
        } catch let error as TVError {
            hideHUD()
            LoggerManager.warning("Connect failed: \(error)", category: "Connect")
            finish(withError: error)
        } catch {
            hideHUD()
            finish(withError: TVError.unreachable.userMessage)
        }
    }

    // MARK: - TVs that show a code

    private func startPairing(_ device: TVDevice) async {
        showHUD("Contacting your TV…")
        let outcome = await AppServices.pairing.start(device)
        hideHUD()

        switch outcome {
        case .awaitingCode(let format, let newChallenge):
            challenge = newChallenge
            presentCodeDialog(for: device, format: format)
        case .noPairingNeeded:
            await connectDirectly(device, message: "Connecting…")
        case .notBuilt, .unavailable:
            finish(withError: "Pairing with this kind of TV is not available yet.")
        case .failed(let error):
            LoggerManager.warning("Pairing start failed: \(error)", category: "Connect")
            finish(withError: error.userMessage)
        }
    }

    private func presentCodeDialog(for device: TVDevice, format: PairingCodeFormat) {
        let dialog = PairingCodeAlertVC(format: format)
        dialog.onPair = { [weak self] code in
            Task { await self?.submit(code: code, for: device) }
        }
        dialog.onCancel = { [weak self] in
            Task { await self?.cancelPairing() }
        }
        codeDialog = dialog
        presenter?.present(dialog, animated: true)
    }

    private func submit(code: String, for device: TVDevice) async {
        guard let dialog = codeDialog, let current = challenge else { return }
        dialog.setLoading(true)

        switch await AppServices.pairing.submit(code: code, challenge: current) {
        case .paired:
            do {
                try await connectAfterPairing(device)
                challenge = nil
                dialog.close { [weak self] in self?.finishConnected() }
            } catch let error as TVError {
                LoggerManager.warning("Connect after pairing failed: \(error)", category: "Connect")
                challenge = nil
                dialog.close { [weak self] in self?.finish(withError: error) }
            } catch {
                challenge = nil
                dialog.close { [weak self] in self?.finish(withError: TVError.unreachable.userMessage) }
            }

        case .wrongCode:
            LoggerManager.info("Wrong pairing code", category: "Connect")
            dialog.showWrongCode()
            await requestNewCode(for: device, current: current, dialog: dialog)

        case .notBuilt:
            challenge = nil
            dialog.close { [weak self] in self?.finish(withError: "Pairing with this kind of TV is not available yet.") }

        case .failed(let error):
            LoggerManager.warning("Pairing submit failed: \(error)", category: "Connect")
            challenge = nil
            dialog.close { [weak self] in self?.finish(withError: error.userMessage) }
        }
    }

    /// A TV needs a moment after pairing before it accepts the control connection (the Android TV
    /// emulator especially), so a few early failures are retried before giving up.
    private func connectAfterPairing(_ device: TVDevice) async throws {
        let retryable: [TVError] = [.notPaired, .unreachable, .timedOut]
        var lastError: TVError = .unreachable
        for attempt in 1...4 {
            do {
                try await AppServices.connection.connect(to: device)
                return
            } catch let error as TVError {
                lastError = error
                LoggerManager.warning("Connect after pairing, attempt \(attempt) failed: \(error)", category: "Connect")
                guard retryable.contains(error), attempt < 4 else { throw error }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        throw lastError
    }

    /// After a wrong code the dialog says a new code will appear, so ask the TV for one.
    private func requestNewCode(for device: TVDevice, current: PairingChallenge, dialog: PairingCodeAlertVC) async {
        await AppServices.pairing.cancel(current)
        switch await AppServices.pairing.start(device) {
        case .awaitingCode(_, let newChallenge):
            challenge = newChallenge
            dialog.setLoading(false)
        case .failed(let error):
            challenge = nil
            dialog.close { [weak self] in self?.finish(withError: error.userMessage) }
        default:
            challenge = nil
            dialog.close { [weak self] in
                self?.finish(withError: "The TV did not show a new code. Please tap the TV again.")
            }
        }
    }

    private func cancelPairing() async {
        if let challenge {
            await AppServices.pairing.cancel(challenge)
        }
        challenge = nil
        isBusy = false
    }

    // MARK: - Finishing

    private func finishConnected() {
        isBusy = false
        LoggerManager.success("TV connected", category: "Connect")
        NavigationManager.shared.showTabs(from: presenter?.navigationController)
    }

    private func finish(withError message: String) {
        isBusy = false
        presenter?.showSimpleAlert(title: "Couldn't connect", message: message)
    }

    private func finish(withError error: TVError) {
        #if DEBUG
        finish(withError: "\(error.userMessage)\n\n[debug: \(error)]")
        #else
        finish(withError: error.userMessage)
        #endif
    }

    // MARK: - Progress overlay

    private func showHUD(_ message: String) {
        guard hud == nil, let view = presenter?.view else { return }
        let overlay = ConnectingHUD(message: message)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hud = overlay
    }

    private func hideHUD() {
        hud?.removeFromSuperview()
        hud = nil
    }
}

/// A dimmed overlay with a spinner and a short message. It also blocks taps while something is in progress.
private final class ConnectingHUD: UIView {

    init(message: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.6)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = CommonColor.white.color
        spinner.startAnimating()

        let label = UILabel()
        label.text = message
        label.font = CommonFont.medium.font(ofSize: 16)
        label.textColor = CommonColor.white.color
        label.textAlignment = .center
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let box = UIView()
        box.backgroundColor = UIColor(hex: 0x10182C)
        box.layer.cornerRadius = 20
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        addSubview(box)

        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: centerXAnchor),
            box.centerYAnchor.constraint(equalTo: centerYAnchor),
            box.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -80),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -28)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
