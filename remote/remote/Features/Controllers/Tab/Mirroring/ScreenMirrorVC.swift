import UIKit
import AVKit
import ReplayKit

/// The Screen Mirroring screen, with two tabs:
/// - **Smart TV:** an Android TV / Google TV mirrors through the app: the button opens the system broadcast
///   picker for the `MirrorBroadcast` extension, and `MirrorController` has the TV play the stream over
///   Google Cast. Any other TV mirrors with AirPlay: Apple doesn't let an app start that by code, so the
///   button opens the system AirPlay picker and the screen explains the steps.
/// - **Web Browser:** the broadcast extension serves a viewer page; the screen shows its address (with Copy
///   and Share) for any browser on the same Wi-Fi.
/// The quality chips apply to both ways of broadcasting. In a DEBUG build in the Simulator, which can't
/// broadcast, the button runs a test stream instead (`MirrorTestStream`).
final class ScreenMirrorVC: UIViewController {

    private enum Tab: Int {
        case smartTV
        case web
    }

    private let cardColor = UIColor(hex: 0x10182C)
    private let mutedColor = UIColor(hex: 0x707A91)
    private let accentColor = UIColor(hex: 0x004BF9)
    /// The note's color when the connected TV can't mirror.
    private static let warningRed = UIColor(hex: 0xE5252A)

    private let routePicker = AVRoutePickerView()
    private let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
    private let segment = RemoteSegmentedControl(titles: [MirrorGuide.smartTVTab, MirrorGuide.webTab])
    private let wifiCard = UIView()
    private let broadcastCard = UIView()
    private let broadcastLabel = UILabel()
    private let urlCard = UIView()
    private let urlLabel = UILabel()
    private let copyButton = HapticButton(type: .custom)
    private let shareButton = HapticButton(type: .custom)
    private let qualityTitleLabel = UILabel()
    private let qualityChips = MirrorQualityChips(selected: AppSettings.mirrorQuality)
    private let openButton = HapticButton(type: .system)
    private let footerLabel = UILabel()

    private var airPlayTask: Task<Void, Never>?
    private var selectedTab: Tab = .smartTV
    /// The connected TV's platform, if one is connected.
    private var platform: TVPlatform?
    /// True when the connected TV mirrors through the broadcast extension instead of AirPlay.
    private var usesBroadcast = false
    /// False when the connected TV was looked for on AirPlay and not found.
    private var airPlayFound = true
    /// Set when the Local Network permission was refused, until the next try.
    private var permissionMessage: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildUI()
        AppServices.mirror.configure(mode: .cast, quality: qualityChips.selected)
        AppServices.mirror.onState = { [weak self] _ in
            self?.refresh()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(onForeground), name: UIApplication.willEnterForegroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(premiumChanged), name: SubscriptionManager.didChangeNotification, object: nil
        )
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkConnectedTV()
        AppServices.mirror.syncWithBroadcast()
        refresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        airPlayTask?.cancel()
    }

    @objc private func onForeground() {
        refresh()
    }

    // MARK: - UI

    private func buildUI() {
        let backButton = HapticButton(type: .custom)
        backButton.applyBackArrowStyle()
        backButton.addTarget(self, action: #selector(onTap_back), for: .touchUpInside)

        let titleLabel = makeLabel(MirrorGuide.screenTitle, font: CommonFont.bold.font(ofSize: 18), color: .white)

        segment.onChange = { [weak self] index in
            self?.switchTab(to: Tab(rawValue: index) ?? .smartTV)
        }

        configureCard(wifiCard, icon: "wifi", label: makeLabel(MirrorGuide.wifiCard, font: CommonFont.semibold.font(ofSize: 14), color: .white))
        broadcastLabel.font = CommonFont.semibold.font(ofSize: 14)
        broadcastLabel.textColor = .white
        broadcastLabel.numberOfLines = 0
        configureCard(broadcastCard, icon: "broadcast", label: broadcastLabel)
        buildURLCard()

        qualityTitleLabel.text = MirrorGuide.qualityTitle
        qualityTitleLabel.font = CommonFont.semibold.font(ofSize: 16)
        qualityTitleLabel.textColor = .white
        qualityChips.onChange = { [weak self] quality in
            self?.qualityChanged(quality)
        }

        let stack = UIStackView(arrangedSubviews: [wifiCard, broadcastCard, urlCard, qualityTitleLabel, qualityChips])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(24, after: urlCard)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        openButton.setTitleColor(.white, for: .normal)
        openButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        openButton.backgroundColor = accentColor
        openButton.layer.cornerRadius = 32
        openButton.addTarget(self, action: #selector(onTap_primary), for: .touchUpInside)

        footerLabel.font = CommonFont.regular.font(ofSize: 12)
        footerLabel.textColor = mutedColor
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0

        // Hidden system pickers; the custom button forwards its tap to the right one.
        for picker in [routePicker, broadcastPicker] as [UIView] {
            picker.alpha = 0.011
            picker.isUserInteractionEnabled = false
        }
        broadcastPicker.preferredExtension = MirrorShared.extensionBundleID
        broadcastPicker.showsMicrophoneButton = false

        let segmentHolder = UIView()
        segmentHolder.translatesAutoresizingMaskIntoConstraints = false
        segmentHolder.addSubview(segment)
        NSLayoutConstraint.activate([
            segment.topAnchor.constraint(equalTo: segmentHolder.topAnchor),
            segment.bottomAnchor.constraint(equalTo: segmentHolder.bottomAnchor),
            segment.leadingAnchor.constraint(equalTo: segmentHolder.leadingAnchor, constant: 16),
            segment.trailingAnchor.constraint(equalTo: segmentHolder.trailingAnchor, constant: -16)
        ])

        [backButton, titleLabel, segmentHolder, scrollView, openButton, footerLabel, routePicker, broadcastPicker].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            segmentHolder.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 20),
            segmentHolder.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            segmentHolder.trailingAnchor.constraint(equalTo: guide.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: segmentHolder.bottomAnchor, constant: 20),
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

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    /// A rounded card with an icon on the left and a label that wraps.
    private func configureCard(_ card: UIView, icon: String, label: UILabel) {
        card.backgroundColor = cardColor
        card.layer.cornerRadius = 20

        let iconView = makeIcon(icon)
        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
    }

    private func makeIcon(_ name: String) -> UIImageView {
        let imageView = UIImageView(image: UIImage(named: name))
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return imageView
    }

    /// The Web Browser tab's card: the instruction, the address in an outlined pill, and Copy / Share.
    private func buildURLCard() {
        urlCard.backgroundColor = cardColor
        urlCard.layer.cornerRadius = 20

        let instruction = makeLabel(MirrorGuide.webCard, font: CommonFont.semibold.font(ofSize: 14), color: .white)
        let header = UIStackView(arrangedSubviews: [makeIcon("web"), instruction])
        header.spacing = 14
        header.alignment = .center

        urlLabel.font = CommonFont.semibold.font(ofSize: 15)
        urlLabel.textColor = .white
        urlLabel.textAlignment = .center
        urlLabel.numberOfLines = 2
        urlLabel.adjustsFontSizeToFitWidth = true
        urlLabel.minimumScaleFactor = 0.7
        let pill = UIView()
        pill.layer.cornerRadius = 26
        pill.layer.borderWidth = 1
        pill.layer.borderColor = accentColor.cgColor
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(urlLabel)
        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            urlLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 8),
            urlLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -8),
            urlLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 16),
            urlLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -16)
        ])

        for (button, title) in [(copyButton, MirrorGuide.copyTitle), (shareButton, MirrorGuide.shareTitle)] {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = CommonFont.semibold.font(ofSize: 15)
            button.backgroundColor = UIColor(hex: 0x1D2538)
            button.layer.cornerRadius = 12
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        copyButton.addTarget(self, action: #selector(onTap_copy), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(onTap_share), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttons.spacing = 12
        buttons.distribution = .fillEqually

        let column = UIStackView(arrangedSubviews: [header, pill, buttons])
        column.axis = .vertical
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        urlCard.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: urlCard.topAnchor, constant: 18),
            column.bottomAnchor.constraint(equalTo: urlCard.bottomAnchor, constant: -16),
            column.leadingAnchor.constraint(equalTo: urlCard.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: urlCard.trailingAnchor, constant: -16)
        ])
    }

    // MARK: - State

    private var isBroadcastRunning: Bool {
        #if DEBUG
        if AppServices.mirror.isTestRunning { return true }
        #endif
        return AppServices.mirror.isBroadcasting
    }

    private var mirroringState: MirrorController.State {
        AppServices.mirror.state
    }

    /// Smart TV tab on a TV that mirrors with AirPlay (or with no TV connected).
    private var isAirPlayFlow: Bool {
        selectedTab == .smartTV && !usesBroadcast
    }

    private func switchTab(to newTab: Tab) {
        selectedTab = newTab
        permissionMessage = nil
        // A running broadcast keeps what it started with; the choice only matters for the next one.
        if !isBroadcastRunning {
            AppServices.mirror.configure(mode: mode(for: newTab), quality: qualityChips.selected)
        }
        refresh()
    }

    private func mode(for tab: Tab) -> MirrorShared.Mode {
        tab == .web ? .web : .cast
    }

    /// 480p is free. A Premium quality needs Premium: a free user is taken to the Subscription screen and the
    /// chips go back to what was chosen before.
    private func qualityChanged(_ quality: MirrorShared.Quality) {
        guard quality.isPremium else {
            applyQuality(quality)
            return
        }
        var isGranted = false
        SubscriptionManager.shared.requirePremium(from: self) { isGranted = true }
        if isGranted {
            applyQuality(quality)
        } else {
            qualityChips.select(AppSettings.mirrorQuality)
        }
    }

    private func applyQuality(_ quality: MirrorShared.Quality) {
        AppSettings.mirrorQuality = quality
        if !isBroadcastRunning {
            AppServices.mirror.configure(mode: mode(for: selectedTab), quality: quality)
        }
    }

    /// Premium turned on or off: show the quality that is allowed now.
    @objc private func premiumChanged() {
        qualityChips.select(AppSettings.mirrorQuality)
        if !isBroadcastRunning {
            AppServices.mirror.configure(mode: mode(for: selectedTab), quality: AppSettings.mirrorQuality)
        }
    }

    /// Redraws everything that depends on the tab, the TV and the broadcast.
    private func refresh() {
        guard isViewLoaded else { return }
        broadcastCard.isHidden = selectedTab != .smartTV
        urlCard.isHidden = selectedTab != .web
        let showsQuality = selectedTab == .web || usesBroadcast
        qualityTitleLabel.isHidden = !showsQuality
        qualityChips.isHidden = !showsQuality
        // The quality is fixed while broadcasting: stop first, then pick another.
        qualityChips.setLocked(isBroadcastRunning)

        broadcastLabel.text = smartTVCardText()
        urlLabel.text = AppServices.mirror.webURL?.absoluteString ?? MirrorGuide.noWiFiAddress
        copyButton.isEnabled = AppServices.mirror.webURL != nil
        shareButton.isEnabled = AppServices.mirror.webURL != nil

        updateButton()
        updateFooter()
    }

    private func smartTVCardText() -> String {
        if platform == nil { return MirrorGuide.connectTVCard }
        return usesBroadcast ? MirrorGuide.broadcastCard : MirrorGuide.airPlayCard
    }

    private func updateButton() {
        var enabled = true
        let title: String
        if isAirPlayFlow {
            title = MirrorGuide.openAirPlayTitle
            enabled = !(platform.map(MirrorGuide.cannotMirror) ?? false)
        } else if isBroadcastRunning {
            title = MirrorGuide.stopBroadcastTitle
        } else if mirroringState == .connectingTV {
            title = AppServices.mirror.config.mode == .web ? "Starting…" : MirrorGuide.connectingTitle
            enabled = false
        } else {
            title = MirrorGuide.startBroadcastTitle
        }
        openButton.setTitle(title, for: .normal)
        openButton.isEnabled = enabled
        openButton.alpha = enabled ? 1 : 0.5
    }

    private func updateFooter() {
        var lines: [String] = []
        var isError = false

        if isAirPlayFlow {
            lines.append(platform.map(MirrorGuide.note(for:)) ?? MirrorGuide.defaultNote)
            isError = platform.map(MirrorGuide.cannotMirror) ?? false
            if !airPlayFound, platform != nil, !isError {
                lines.append("Your TV wasn't found on AirPlay just now. Check that AirPlay is on and it's on the same Wi-Fi.")
                isError = true
            }
        } else if selectedTab == .smartTV, let platform {
            lines.append(MirrorGuide.note(for: platform))
        }

        if case .failed(let message) = mirroringState, !isAirPlayFlow {
            lines.append(message)
            isError = true
        }
        if let permissionMessage, !isAirPlayFlow {
            lines.append(permissionMessage)
            isError = true
        }
        lines.append(MirrorGuide.privacyNote)

        footerLabel.text = lines.joined(separator: "\n\n")
        footerLabel.textColor = isError ? Self.warningRed : mutedColor
    }

    // MARK: - Actions

    @objc private func onTap_back() {
        navigationController?.popViewController(animated: true)
    }

    /// The big button: AirPlay, or start / stop a broadcast.
    @objc private func onTap_primary() {
        if isAirPlayFlow {
            guard ClickLimitManager.shared.allowTap(for: .screenMirror, from: self) else { return }
            openAirPlay()
            return
        }
        let mirror = AppServices.mirror
        permissionMessage = nil
        if !isBroadcastRunning {
            mirror.configure(mode: mode(for: selectedTab), quality: qualityChips.selected)
        }

        #if DEBUG && targetEnvironment(simulator)
        // The Simulator can't broadcast: run the in-app test stream instead (`MirrorTestStream`).
        if mirror.isTestRunning {
            mirror.stopSimulatorTest()
        } else {
            guard ClickLimitManager.shared.allowTap(for: .screenMirror, from: self) else { return }
            mirror.startSimulatorTest()
        }
        refresh()
        return
        #else
        if isBroadcastRunning {
            openBroadcastPicker()
            return
        }
        Task { [weak self] in
            // The TV or the browser reads the stream from this phone over the local network.
            guard await mirror.checkLocalNetwork() else {
                self?.permissionMessage = "Local Network access is off. Turn it on in Settings so other devices can reach this phone."
                self?.refresh()
                return
            }
            guard let self, ClickLimitManager.shared.allowTap(for: .screenMirror, from: self) else { return }
            self.openBroadcastPicker()
        }
        #endif
    }

    /// Neither `AVRoutePickerView` nor `RPSystemBroadcastPickerView` has a public "open" call, so tap its
    /// inner button. The broadcast picker shows Start Broadcast, or Stop Broadcast while one runs.
    private func openAirPlay() {
        routePicker.subviews.compactMap { $0 as? UIButton }.first?.sendActions(for: .touchUpInside)
    }

    private func openBroadcastPicker() {
        broadcastPicker.subviews.compactMap { $0 as? UIButton }.first?.sendActions(for: .allTouchEvents)
    }

    @objc private func onTap_copy() {
        guard let url = AppServices.mirror.webURL else { return }
        UIPasteboard.general.string = url.absoluteString
        HapticManager.trigger(.success)
        copyButton.setTitle(MirrorGuide.copiedTitle, for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton.setTitle(MirrorGuide.copyTitle, for: .normal)
        }
    }

    @objc private func onTap_share() {
        guard let url = AppServices.mirror.webURL else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = shareButton
        present(sheet, animated: true)
    }

    // MARK: - Connected TV

    private func checkConnectedTV() {
        airPlayTask?.cancel()
        airPlayTask = Task { [weak self] in
            guard let device = await AppServices.connection.activeDevice else {
                self?.platform = nil
                self?.usesBroadcast = false
                self?.refresh()
                return
            }
            self?.platform = device.platform
            self?.usesBroadcast = MirrorGuide.usesBroadcastMirroring(device.platform)
            self?.airPlayFound = true
            self?.refresh()
            // Broadcast mirroring and a TV that can't mirror need no AirPlay check.
            guard self?.usesBroadcast == false, !MirrorGuide.cannotMirror(device.platform) else { return }
            let found = await AirPlayFinder().isAirPlayAvailable(at: device.host)
            guard !Task.isCancelled else { return }
            self?.airPlayFound = found
            self?.refresh()
        }
    }
}
