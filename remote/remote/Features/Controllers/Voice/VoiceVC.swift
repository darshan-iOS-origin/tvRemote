import UIKit

/// Full-screen voice input. Shows "Listening...." while the phone's microphone is on, then the words that
/// were heard. Built in code (no storyboard scene); open it with `NavigationManager.showVoice(from:)`.
final class VoiceVC: UIViewController {

    private static let placeholder = "Listening"

    private let backButton = HapticButton(type: .custom)
    private let textLabel = UILabel()
    private let micButton = HapticButton(type: .custom)
    private let dots = DotAnimator()

    private var assistant: VoiceAssistant?
    private var didStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        setupViews()
        NotificationCenter.default.addObserver(self, selector: #selector(stopListening),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        startListening()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Swipe-back, a tab change or a presented screen: the microphone must not stay on.
        if isMovingFromParent || isBeingDismissed || navigationController == nil { stopListening() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backButton.updateGlassFallbackCorners()
    }

    deinit {
        assistant?.stop()
    }

    // MARK: - Layout

    private func setupViews() {
        backButton.setImage(IconsHelper.image(systemName: "chevron.left", pointSize: 14), for: .normal)
        backButton.tintColor = CommonColor.white.color
        backButton.applyGlassStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)
        backButton.accessibilityLabel = "Back"

        textLabel.numberOfLines = 0
        textLabel.font = CommonFont.bold.font(ofSize: 26)
        textLabel.textColor = CommonColor.secondaryGray.color

        let icon = UIImage(named: "ic_record") ?? IconsHelper.image(systemName: "mic.fill", pointSize: 28)
        micButton.setImage(icon?.withRenderingMode(UIImage(named: "ic_record") == nil ? .alwaysTemplate : .alwaysOriginal), for: .normal)
        micButton.tintColor = CommonColor.white.color
        micButton.imageView?.contentMode = .scaleAspectFit
        micButton.contentHorizontalAlignment = .fill
        micButton.contentVerticalAlignment = .fill
        if UIImage(named: "ic_record") == nil {
            // No asset yet: draw the blue circle the design shows.
            micButton.backgroundColor = CommonColor.primaryBlue.color
            micButton.layer.cornerRadius = 32
            micButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        }
        micButton.addTarget(self, action: #selector(onTap_mic), for: .touchUpInside)
        micButton.accessibilityLabel = "Record voice"

        [backButton, textLabel, micButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            textLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            textLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 40),

            micButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            micButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -40),
            micButton.widthAnchor.constraint(equalToConstant: 64),
            micButton.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    // MARK: - Voice

    private func startListening() {
        guard let device = AppServices.connection.activeDevice else {
            showSimpleAlert(title: "Voice", message: TVError.notConnected.userMessage) { [weak self] in self?.close() }
            return
        }
        guard ConnectionManager.canUseVoice(device.platform) else {
            showSimpleAlert(title: "Voice", message: "Voice control is not available for this TV yet.") { [weak self] in self?.close() }
            return
        }
        let voice = assistant ?? makeAssistant(platform: device.platform)
        assistant = voice
        showPlaceholder()
        voice.start()
    }

    private func makeAssistant(platform: TVPlatform) -> VoiceAssistant {
        let voice = VoiceAssistant(connection: AppServices.connection, platform: platform)
        voice.onStateChange = { [weak self] state in
            Task { @MainActor in self?.stateChanged(state) }
        }
        voice.onHeard = { [weak self] words in
            Task { @MainActor in self?.showHeard(words) }
        }
        voice.onFailure = { [weak self] error in
            Task { @MainActor in self?.handle(error) }
        }
        return voice
    }

    private func stateChanged(_ state: VoiceAssistant.State) {
        if state == .idle { dots.stop() }
    }

    private func showPlaceholder() {
        textLabel.textColor = CommonColor.secondaryGray.color
        dots.start(on: textLabel, baseText: Self.placeholder, maxDots: 4)
    }

    private func showHeard(_ words: String) {
        dots.stop()
        textLabel.textColor = CommonColor.white.color
        textLabel.text = words
    }

    private func handle(_ error: Error) {
        dots.stop()
        switch error {
        case VoiceAssistantError.nothingHeard:
            textLabel.textColor = CommonColor.secondaryGray.color
            textLabel.text = "Didn't catch that. Tap the mic to try again."
        case VoiceAssistantError.microphoneDenied, VoiceAssistantError.speechDenied:
            textLabel.text = nil
            showPermissionAlert(speech: error as? VoiceAssistantError == .speechDenied)
        default:
            textLabel.text = nil
            showSimpleAlert(title: "Voice", message: Self.message(for: error))
        }
    }

    private func showPermissionAlert(speech: Bool) {
        let what = speech ? "Speech Recognition" : "the Microphone"
        let alert = UIAlertController(title: "Allow access",
                                      message: "Turn on \(what) for this app in Settings to control your TV with your voice.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        })
        present(alert, animated: true)
    }

    private static func message(for error: Error) -> String {
        if let error = error as? VoiceAssistantError { return error.userMessage }
        if let error = error as? TVError { return error.userMessage }
        return "Something went wrong with voice. Please try again."
    }

    // MARK: - Actions

    @objc private func onTap_mic() {
        guard let assistant else { return startListening() }
        if assistant.state == .idle {
            textLabel.text = nil
            startListening()
        } else {
            assistant.stop()
        }
    }

    @objc private func onTap_back() {
        stopListening()
        close()
    }

    @objc private func stopListening() {
        dots.stop()
        assistant?.stop()
    }

    private func close() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
