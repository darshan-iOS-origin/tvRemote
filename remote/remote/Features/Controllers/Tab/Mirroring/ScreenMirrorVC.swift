import UIKit
import AVKit
import ReplayKit

/// Guides the user through iPhone screen mirroring. Apple doesn't let an app start AirPlay mirroring
/// by code, so the button opens the system AirPlay picker and the screen explains the steps.
/// Android TV / Google TV have no AirPlay: for them the button opens the system broadcast picker for the
/// app's `MirrorBroadcast` extension, and `MirrorController` has the TV play the stream over Google Cast.
final class ScreenMirrorVC: UIViewController {

    private let cardColor = UIColor(hex: 0x10182C)
    private let mutedColor = UIColor(hex: 0x707A91)
    private let accentColor = UIColor(hex: 0x004BF9)
    /// The note's color when the connected TV can't mirror.
    private static let warningRed = UIColor(hex: 0xE5252A)

    private let routePicker = AVRoutePickerView()
    private let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
    private let openButton = HapticButton(type: .system)
    private let stepsStack = UIStackView()
    private let stopLabel = UILabel()
    private let footerLabel = UILabel()
    private var airPlayTask: Task<Void, Never>?
    /// True when the connected TV mirrors through the broadcast extension instead of AirPlay.
    private var usesBroadcast = false
    private var connectedNote = MirrorGuide.defaultNote

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildUI()
        footerLabel.text = MirrorGuide.defaultNote
        AppServices.mirror.onState = { [weak self] _ in
            self?.updateBroadcastUI()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkConnectedTV()
        AppServices.mirror.syncWithBroadcast()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        airPlayTask?.cancel()
    }

    // MARK: - UI

    private func buildUI() {
        let backButton = HapticButton(type: .system)
        backButton.setImage(IconsHelper.image(systemName: "chevron.left", pointSize: 18), for: .normal)
        backButton.tintColor = .white
        backButton.applyGlassStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = makeLabel(MirrorGuide.screenTitle, font: CommonFont.bold.font(ofSize: 18), color: .white)

        openButton.setTitle(MirrorGuide.openAirPlayTitle, for: .normal)
        openButton.setTitleColor(.white, for: .normal)
        openButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        openButton.backgroundColor = accentColor
        openButton.layer.cornerRadius = 32
        openButton.addTarget(self, action: #selector(onTap_openAirPlay), for: .touchUpInside)
        openButton.translatesAutoresizingMaskIntoConstraints = false

        footerLabel.font = CommonFont.regular.font(ofSize: 12)
        footerLabel.textColor = mutedColor
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0

        // Hidden system picker; the custom button forwards its tap to it.
        routePicker.alpha = 0.011
        routePicker.isUserInteractionEnabled = false
        routePicker.translatesAutoresizingMaskIntoConstraints = false
        broadcastPicker.preferredExtension = MirrorShared.extensionBundleID
        broadcastPicker.showsMicrophoneButton = false
        broadcastPicker.alpha = 0.011
        broadcastPicker.isUserInteractionEnabled = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeWarningBanner())
        stack.setCustomSpacing(28, after: stack.arrangedSubviews[0])
        stack.addArrangedSubview(makeLabel(MirrorGuide.howToTitle, font: CommonFont.semibold.font(ofSize: 16), color: .white))
        stack.setCustomSpacing(14, after: stack.arrangedSubviews[1])
        stepsStack.axis = .vertical
        stepsStack.spacing = 16
        stack.addArrangedSubview(stepsStack)
        showSteps(MirrorGuide.stepItems)
        stopLabel.text = MirrorGuide.stopHint
        stopLabel.font = CommonFont.regular.font(ofSize: 12)
        stopLabel.textColor = mutedColor
        stopLabel.numberOfLines = 0
        stopLabel.textAlignment = .center
        stack.addArrangedSubview(stopLabel)

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        [backButton, titleLabel, scrollView, openButton, footerLabel, routePicker, broadcastPicker].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: openButton.topAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            footerLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 28),
            footerLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -28),
            footerLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
            openButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            openButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            openButton.heightAnchor.constraint(equalToConstant: 64),
            openButton.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -16),

            routePicker.widthAnchor.constraint(equalToConstant: 1),
            routePicker.heightAnchor.constraint(equalToConstant: 1),
            routePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            routePicker.topAnchor.constraint(equalTo: view.topAnchor),
            broadcastPicker.widthAnchor.constraint(equalToConstant: 1),
            broadcastPicker.heightAnchor.constraint(equalToConstant: 1),
            broadcastPicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            broadcastPicker.topAnchor.constraint(equalTo: view.topAnchor)
        ])
    }

    private func showSteps(_ items: [(title: String, detail: String)]) {
        stepsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in items.enumerated() {
            stepsStack.addArrangedSubview(makeStepCard(number: index + 1, title: item.title, detail: item.detail))
        }
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func makeWarningBanner() -> UIView {
        let banner = UIView()
        banner.backgroundColor = UIColor(hex: 0x2E2010)
        banner.layer.cornerRadius = 20

        let icon = UIImageView(image: UIImage(named: "ic_warning")
            ?? IconsHelper.image(systemName: "exclamationmark.triangle.fill", pointSize: 28))
        icon.tintColor = UIColor(hex: 0xFFB800)
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = makeLabel(MirrorGuide.warning, font: CommonFont.regular.font(ofSize: 14), color: .white)
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(row)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),
            row.topAnchor.constraint(equalTo: banner.topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -18),
            row.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16)
        ])
        return banner
    }

    private func makeStepCard(number: Int, title: String, detail: String) -> UIView {
        let card = UIView()
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 24

        let badge = UILabel()
        badge.text = "\(number)"
        badge.font = CommonFont.semibold.font(ofSize: 16)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = accentColor
        badge.layer.cornerRadius = 14
        badge.clipsToBounds = true

        let titleLabel = makeLabel(title, font: CommonFont.semibold.font(ofSize: 16), color: .white)
        let detailLabel = makeLabel(detail, font: CommonFont.regular.font(ofSize: 15), color: mutedColor)
        let texts = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        texts.axis = .vertical
        texts.spacing = 4

        let row = UIStackView(arrangedSubviews: [badge, texts])
        row.spacing = 16
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 28),
            badge.heightAnchor.constraint(equalToConstant: 28),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20)
        ])
        return card
    }

    // MARK: - Actions

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    /// Neither `AVRoutePickerView` nor `RPSystemBroadcastPickerView` has a public "open" call, so tap its
    /// inner button. The broadcast picker shows Start Broadcast, or Stop Broadcast while one runs.
    @objc private func onTap_openAirPlay() {
        if usesBroadcast {
            let button = broadcastPicker.subviews.compactMap { $0 as? UIButton }.first
            button?.sendActions(for: .allTouchEvents)
        } else {
            let button = routePicker.subviews.compactMap { $0 as? UIButton }.first
            button?.sendActions(for: .touchUpInside)
        }
    }

    // MARK: - Broadcast mirroring

    /// Switches the steps and the button between AirPlay and broadcast mirroring.
    private func applyMirroringMode() {
        showSteps(usesBroadcast ? MirrorGuide.broadcastStepItems : MirrorGuide.stepItems)
        stopLabel.text = usesBroadcast ? MirrorGuide.broadcastStopHint : MirrorGuide.stopHint
        updateBroadcastUI()
    }

    /// The button title and the footer follow the broadcast's state.
    private func updateBroadcastUI() {
        guard usesBroadcast else {
            openButton.setTitle(MirrorGuide.openAirPlayTitle, for: .normal)
            return
        }
        switch AppServices.mirror.state {
        case .connectingTV:
            openButton.setTitle(MirrorGuide.connectingTitle, for: .normal)
            footerLabel.text = connectedNote
            footerLabel.textColor = mutedColor
        case .mirroring:
            openButton.setTitle(MirrorGuide.stopMirroringTitle, for: .normal)
            footerLabel.text = connectedNote
            footerLabel.textColor = mutedColor
        case .failed(let message):
            openButton.setTitle(
                AppServices.mirror.isBroadcasting ? MirrorGuide.stopMirroringTitle : MirrorGuide.startMirroringTitle,
                for: .normal
            )
            footerLabel.text = message
            footerLabel.textColor = Self.warningRed
        case .idle:
            openButton.setTitle(
                AppServices.mirror.isBroadcasting ? MirrorGuide.stopMirroringTitle : MirrorGuide.startMirroringTitle,
                for: .normal
            )
            footerLabel.text = connectedNote
            footerLabel.textColor = mutedColor
        }
    }

    // MARK: - Connected TV

    private func checkConnectedTV() {
        airPlayTask?.cancel()
        footerLabel.textColor = mutedColor
        airPlayTask = Task { [weak self] in
            guard let device = await AppServices.connection.activeDevice else { return }
            self?.connectedNote = MirrorGuide.note(for: device.platform)
            self?.usesBroadcast = MirrorGuide.usesBroadcastMirroring(device.platform)
            self?.applyMirroringMode()
            // Broadcast mirroring doesn't need AirPlay, so there is nothing to look for.
            if self?.usesBroadcast == true { return }
            self?.footerLabel.text = MirrorGuide.note(for: device.platform)
            // A TV that can't mirror gets its note in red straight away.
            self?.footerLabel.textColor = MirrorGuide.cannotMirror(device.platform) ? Self.warningRed : self?.mutedColor
            let found = await AirPlayFinder().isAirPlayAvailable(at: device.host)
            guard !Task.isCancelled, !found else { return }
            self?.footerLabel.text = MirrorGuide.note(for: device.platform)
                + "\n\nYour TV wasn't found on AirPlay just now. Check that AirPlay is on and it's on the same Wi-Fi."
            self?.footerLabel.textColor = Self.warningRed
        }
    }
}
