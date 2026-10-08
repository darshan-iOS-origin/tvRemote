import UIKit

/// The Remote tab: the on-screen TV remote from the Figma "Remote" frame. A fixed header sits above a
/// scrolling stack of keys. Each key sends its `KeyCommand` to the connected TV through `ConnectionManager`.
/// Cast opens the Cast screen and voice opens the Voice screen.
class RemoteVC: UIViewController {

    // MARK: - Metrics (points, from the 393 pt wide Figma frame)

    private let sideMargin: CGFloat = 20
    /// The key rows are inset a little more than the sections.
    private let keyRowMargin: CGFloat = 24
    private let headerHeight: CGFloat = 60
    private let headerButtonSize: CGFloat = 40
    private let headerButtonSpacing: CGFloat = 15

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    /// Header buttons with the glass look; the blur fallback needs its corners refreshed after layout.
    private var glassButtons: [HapticButton] = []
    /// Every key that sends something, so the ones the TV lacks can be dimmed.
    private var keyButtons: [RemoteKeyButton] = []
    /// True while an error alert is up, so a held key that keeps failing shows only one.
    private var isShowingError = false
    /// The two faces of the middle of the remote: the d-pad (Buttons) and the touchpad (Touchpad).
    private var dpad: RemoteDPadView?
    private var touchpad: RemoteTouchpadView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()

        let header = buildHeader()
        buildScrollView(below: header)
        buildContent()
        glassButtons.forEach { $0.applyGlassStyle() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAvailableKeys()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        glassButtons.forEach { $0.updateGlassFallbackCorners() }
    }

    // MARK: - Sending keys

    /// Sends one key to the TV. Without a connected TV it asks the user to connect first.
    private func send(_ key: KeyCommand) {
        Task { [weak self] in
            guard await AppServices.connection.activeDevice != nil else {
                self?.showConnectionRequired()
                return
            }
            do {
                try await AppServices.connection.send(key)
            } catch let error as TVError {
                LoggerManager.warning("Sending \(key.rawValue) failed: \(error)", category: "Remote")
                self?.showError(error.userMessage)
            } catch {
                self?.showError(TVError.unreachable.userMessage)
            }
        }
    }

    /// Opens the Cast screen. Casting needs a connected TV, so without one the user is asked to connect first.
    @objc private func onTap_cast() {
        Task { [weak self] in
            guard await AppServices.connection.activeDevice != nil else {
                self?.showConnectionRequired()
                return
            }
            NavigationManager.shared.showCast(from: self?.navigationController)
        }
    }

    /// Opens the Voice screen. Needs a connected TV whose platform supports voice.
    @objc private func onTap_voice() {
        Task { [weak self] in
            guard let device = await AppServices.connection.activeDevice else {
                self?.showConnectionRequired()
                return
            }
            guard ConnectionManager.canUseVoice(device.platform) else {
                self?.showError("Voice control is not available for this TV yet.")
                return
            }
            NavigationManager.shared.showVoice(from: self?.navigationController)
        }
    }

    /// "+" in the header: scan for another TV. Connecting to it drops the current one.
    @objc private func onTap_addTV() {
        NavigationManager.shared.showScanning(from: navigationController, addingTV: true)
    }

    /// Opens the Screen Mirroring screen. Like Cast, it needs a connected TV first.
    @objc private func onTap_screenMirror() {
        Task { [weak self] in
            guard await AppServices.connection.activeDevice != nil else {
                self?.showConnectionRequired()
                return
            }
            NavigationManager.shared.showScreenMirror(from: self?.navigationController)
        }
    }

    private func showError(_ message: String) {
        guard !isShowingError, presentedViewController == nil, tabBarController?.presentedViewController == nil else { return }
        isShowingError = true
        showSimpleAlert(title: "Remote", message: message) { [weak self] in self?.isShowingError = false }
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

    /// Dims the keys the connected TV does not have. With no TV, or one we know nothing about, every key stays on.
    private func refreshAvailableKeys() {
        Task { [weak self] in
            let platform = await AppServices.connection.activeDevice?.platform
            guard let self else { return }
            for button in self.keyButtons {
                guard let key = button.key, let platform else {
                    button.setAvailable(true)
                    continue
                }
                button.setAvailable(ConnectionManager.supports(key, on: platform))
            }
        }
    }

    /// Hooks a key button up to `send` and remembers it for dimming.
    @discardableResult
    private func bind(_ button: RemoteKeyButton, to key: KeyCommand) -> RemoteKeyButton {
        button.bind(key) { [weak self] in self?.send($0) }
        keyButtons.append(button)
        return button
    }

    // MARK: - Header

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
        add.addTarget(self, action: #selector(onTap_addTV), for: .touchUpInside)

        let actions = UIStackView(arrangedSubviews: [keyboard, history, add])
        actions.spacing = headerButtonSpacing
        actions.setContentHuggingPriority(.required, for: .horizontal)

        // The empty spacer is the only view that stretches, which pushes the buttons to the right edge.
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

    // MARK: - Scrolling content

    /// The scroll view reaches the bottom of the screen, so it adds the tab bar's inset on its own.
    private func buildScrollView(below header: UIView) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 25
        contentStack.isLayoutMarginsRelativeArrangement = true
        // 12.6 pt gap under the header; 24 pt of breathing room above the tab bar.
        contentStack.layoutMargins = UIEdgeInsets(top: 12.6, left: 0, bottom: 24, right: 0)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func buildContent() {
        let segment = RemoteSegmentedControl(titles: ["Buttons", "Touchpad"])
        let topRow = inset(makeTopRow(), by: keyRowMargin)
        let cluster = makeCluster()
        segment.onChange = { [weak self] index in self?.showCentre(touchpad: index == 1) }
        let transport = inset(makeTransportRow(), by: keyRowMargin)

        contentStack.addArrangedSubview(inset(segment, by: sideMargin))
        contentStack.addArrangedSubview(topRow)
        contentStack.addArrangedSubview(cluster)
        contentStack.addArrangedSubview(transport)
        contentStack.setCustomSpacing(30, after: topRow)
        contentStack.setCustomSpacing(30, after: cluster)

        // The first section's title sits 30 pt under the transport row, measured to its capitals.
        let sections = UIStackView(arrangedSubviews: makeSections())
        sections.axis = .vertical
        sections.spacing = RemoteSectionView.sectionSpacing
        contentStack.addArrangedSubview(inset(sections, by: sideMargin))
        contentStack.setCustomSpacing(30 - RemoteSectionView.titleLinePadding, after: transport)
    }

    /// Swaps only the middle of the remote; the rest of the screen stays as it is.
    private func showCentre(touchpad showTouchpad: Bool) {
        guard let dpad, let touchpad else { return }
        let incoming: UIView = showTouchpad ? touchpad : dpad
        let outgoing: UIView = showTouchpad ? dpad : touchpad
        incoming.isHidden = false
        UIView.animate(withDuration: 0.2, animations: {
            incoming.alpha = 1
            outgoing.alpha = 0
        }, completion: { _ in
            // Only hide it if the user has not switched back in the meantime.
            if outgoing.alpha == 0 { outgoing.isHidden = true }
        })
    }

    // MARK: - Key rows

    /// Power, cast, voice and copy.
    private func makeTopRow() -> UIView {
        let power = RemoteKeyButton(
            icon: .image("ic_remote_power"),
            fill: .linear(top: RemoteTheme.redTop, bottom: RemoteTheme.redBottom),
            borderColor: UIColor.white.withAlphaComponent(0.3),
            width: 60,
            height: 60
        )
        bind(power, to: .power)
        let cast = circleKey(icon: .image("ic_remote_cast"), size: 60)
        cast.addTarget(self, action: #selector(onTap_cast), for: .touchUpInside)
        let voice = circleKey(icon: .image("ic_remote_voice"), size: 60)
        voice.addTarget(self, action: #selector(onTap_voice), for: .touchUpInside)
        let copy = circleKey(icon: .image("ic_remote_copy", transform: CGAffineTransform(scaleX: -1, y: 1)), size: 60)
        copy.addTarget(self, action: #selector(onTap_screenMirror), for: .touchUpInside)
        return spacedRow([power, cast, voice, copy])
    }

    /// Volume on the left, the d-pad in the middle, channel on the right.
    private func makeCluster() -> UIView {
        let cluster = UIView()
        cluster.translatesAutoresizingMaskIntoConstraints = false

        let send: (KeyCommand) -> Void = { [weak self] in self?.send($0) }
        let dpad = RemoteDPadView(onKey: send)
        let touchpad = RemoteTouchpadView(onKey: send)
        touchpad.alpha = 0
        touchpad.isHidden = true
        self.dpad = dpad
        self.touchpad = touchpad
        let volume = RemoteRockerView(
            top: .image("ic_remote_vol_plus"),
            topKey: .volumeUp,
            title: "VOL",
            bottom: .image("ic_remote_vol_minus"),
            bottomKey: .volumeDown,
            onKey: send
        )
        // Both channel chevrons are drawn pointing sideways and turned a quarter turn: up and down.
        let rightAngle = CGAffineTransform(rotationAngle: .pi / 2)
        let channel = RemoteRockerView(
            top: .image("ic_remote_ch_up", transform: rightAngle),
            topKey: .channelUp,
            title: "CH",
            bottom: .image("ic_remote_ch_down", transform: rightAngle),
            bottomKey: .channelDown,
            onKey: send
        )
        keyButtons += dpad.keyButtons + volume.keyButtons + channel.keyButtons
        [dpad, touchpad, volume, channel].forEach(cluster.addSubview)

        NSLayoutConstraint.activate([
            cluster.heightAnchor.constraint(equalToConstant: RemoteDPadView.diameter),
            dpad.centerXAnchor.constraint(equalTo: cluster.centerXAnchor),
            dpad.centerYAnchor.constraint(equalTo: cluster.centerYAnchor),
            touchpad.centerXAnchor.constraint(equalTo: cluster.centerXAnchor),
            touchpad.centerYAnchor.constraint(equalTo: cluster.centerYAnchor),
            volume.leadingAnchor.constraint(equalTo: cluster.leadingAnchor, constant: keyRowMargin),
            volume.centerYAnchor.constraint(equalTo: cluster.centerYAnchor),
            channel.trailingAnchor.constraint(equalTo: cluster.trailingAnchor, constant: -keyRowMargin),
            channel.centerYAnchor.constraint(equalTo: cluster.centerYAnchor)
        ])
        return cluster
    }

    /// Previous, play, next and stop. These keys have a thinner border than the rest.
    private func makeTransportRow() -> UIView {
        let flip = CGAffineTransform(scaleX: -1, y: 1)
        let keys = [
            circleKey(icon: .image("ic_remote_skip", transform: flip), size: 60, borderWidth: 1, key: .previous),
            circleKey(icon: .image("ic_remote_play"), size: 60, borderWidth: 1, key: .playPause),
            circleKey(icon: .image("ic_remote_skip"), size: 60, borderWidth: 1, key: .next),
            circleKey(icon: .image("ic_remote_stop"), size: 60, borderWidth: 1, key: .stop)
        ]
        return spacedRow(keys)
    }

    private func makeSections() -> [UIView] {
        [
            RemoteSectionView(title: "TV", content: makeTVRow()),
            RemoteSectionView(title: "Navigation", content: makeNavigationRow()),
            RemoteSectionView(title: "Input", content: makeInputRow()),
            RemoteSectionView(title: "Playback", content: makePlaybackRow()),
            RemoteSectionView(title: "Colours", content: makeColoursRow()),
            RemoteSectionView(title: "More", content: makeMoreRow())
        ]
    }

    private func makeTVRow() -> UIView {
        let font = CommonFont.semibold.font(ofSize: 18)
        let liveTV = bind(RemoteKeyButton(title: "LIVE TV", font: font, cornerRadius: 15, height: 56), to: .liveTV)
        let input = bind(RemoteKeyButton(title: "INPUT", font: font, cornerRadius: 15, height: 56), to: .input)
        return equalRow([liveTV, input], spacing: 15)
    }

    private func makeNavigationRow() -> UIView {
        let keys: [(icon: String, key: KeyCommand)] = [
            ("ic_remote_nav_back", .back),
            ("ic_remote_nav_home", .home),
            ("ic_remote_nav_notes", .menu),
            ("ic_remote_nav_info", .info)
        ]
        return spacedRow(keys.map { circleKey(icon: .image($0.icon), size: 72, key: $0.key) })
    }

    /// The design repeats "HDMI 1" four times; the four ports are numbered here.
    private func makeInputRow() -> UIView {
        let font = CommonFont.medium.font(ofSize: 11)
        let ports: [KeyCommand] = [.hdmi1, .hdmi2, .hdmi3, .hdmi4]
        let keys = ports.enumerated().map { index, port in
            cardKey(icon: .image("ic_remote_hdmi"), title: "HDMI \(index + 1)", font: font, spacing: 10, height: 79, key: port)
        }
        return equalRow(keys, spacing: 13.5)
    }

    private func makePlaybackRow() -> UIView {
        let flip = CGAffineTransform(scaleX: -1, y: 1)
        let small = CommonFont.medium.font(ofSize: 11)
        let large = CommonFont.medium.font(ofSize: 12)
        let keys = [
            cardKey(icon: .image("ic_remote_rewind"), title: "Back Forward", font: large, spacing: 12, height: 81, key: .rewind),
            cardKey(icon: .image("ic_remote_play"), title: "Play / Pause", font: small, spacing: 12, height: 81, key: .playPause),
            cardKey(icon: .image("ic_remote_rewind", transform: flip), title: "Fast Forward", font: large, spacing: 12, height: 81, key: .fastForward)
        ]
        return equalRow(keys, spacing: 13.5)
    }

    private func makeColoursRow() -> UIView {
        let font = CommonFont.medium.font(ofSize: 11)
        let keys = Self.colourKeys.map { colour in
            cardKey(
                icon: .dot(top: UIColor(hex: colour.dotTop), bottom: UIColor(hex: colour.dotBottom)),
                title: colour.title,
                font: font,
                spacing: 10,
                height: 67,
                fill: .radial(colour.tint, opacity: 0.15),
                key: colour.key
            )
        }
        return equalRow(keys, spacing: 13.5)
    }

    /// The Subtitle key is half a row wide and sits on the left.
    private func makeMoreRow() -> UIView {
        let subtitle = RemoteKeyButton(
            icon: .layers([
                (name: "ic_remote_subtitle_body", center: CGPoint(x: 14, y: 14)),
                (name: "ic_remote_subtitle_lines", center: CGPoint(x: 14, y: 17.74))
            ]),
            title: "Subtitle",
            font: CommonFont.semibold.font(ofSize: 14),
            layout: .iconBeside(spacing: 10, offsetX: -20.5),
            cornerRadius: 15,
            height: 60
        )
        bind(subtitle, to: .subtitles)
        let holder = UIView()
        holder.addSubview(subtitle)
        NSLayoutConstraint.activate([
            subtitle.topAnchor.constraint(equalTo: holder.topAnchor),
            subtitle.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
            subtitle.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
            subtitle.widthAnchor.constraint(equalTo: holder.widthAnchor, multiplier: 0.5, constant: -7.5)
        ])
        return holder
    }

    // MARK: - Building blocks

    private func circleKey(
        icon: RemoteKeyButton.Icon,
        size: CGFloat,
        borderWidth: CGFloat = RemoteTheme.keyBorderWidth,
        key: KeyCommand? = nil
    ) -> RemoteKeyButton {
        let button = RemoteKeyButton(icon: icon, borderWidth: borderWidth, width: size, height: size)
        if let key { bind(button, to: key) }
        return button
    }

    private func cardKey(
        icon: RemoteKeyButton.Icon,
        title: String,
        font: UIFont,
        spacing: CGFloat,
        height: CGFloat,
        fill: RemoteKeyButton.Fill = .box,
        key: KeyCommand
    ) -> RemoteKeyButton {
        let button = RemoteKeyButton(
            icon: icon,
            title: title,
            font: font,
            layout: .iconAbove(spacing: spacing),
            fill: fill,
            cornerRadius: 17,
            height: height
        )
        return bind(button, to: key)
    }

    /// Fixed-size keys spread across the row; on a narrower phone the gaps shrink, not the keys.
    private func spacedRow(_ keys: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: keys)
        row.distribution = .equalSpacing
        row.alignment = .center
        return row
    }

    /// Keys that share the row width equally.
    private func equalRow(_ keys: [UIView], spacing: CGFloat) -> UIStackView {
        let row = UIStackView(arrangedSubviews: keys)
        row.distribution = .fillEqually
        row.alignment = .center
        row.spacing = spacing
        return row
    }

    /// Wraps `content` with equal left and right margins.
    private func inset(_ content: UIView, by margin: CGFloat) -> UIView {
        let container = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: margin),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -margin)
        ])
        return container
    }
}

// MARK: - Colour keys

private extension RemoteVC {

    struct ColourKey {
        let title: String
        let key: KeyCommand
        /// Top and bottom of the round swatch.
        let dotTop: UInt32
        let dotBottom: UInt32
        /// The key's soft background tint (drawn at 15% opacity).
        let tint: RemoteGradientView.Radial

        init(
            title: String,
            key: KeyCommand,
            dotTop: UInt32,
            dotBottom: UInt32,
            stops: [(color: UInt32, location: CGFloat)],
            centerY: CGFloat,
            endX: CGFloat
        ) {
            self.title = title
            self.key = key
            self.dotTop = dotTop
            self.dotBottom = dotBottom
            tint = RemoteGradientView.Radial(
                colors: stops.map { UIColor(hex: $0.color) },
                locations: stops.map(\.location),
                center: CGPoint(x: 0.5, y: centerY),
                end: CGPoint(x: endX, y: 1)
            )
        }
    }

    static let colourKeys: [ColourKey] = [
        ColourKey(
            title: "Blue", key: .blue, dotTop: 0x0169F1, dotBottom: 0x003090,
            stops: [(0x0169F1, 0), (0x014DC1, 0.5), (0x003090, 1)],
            centerY: 0.387, endX: 1.113
        ),
        ColourKey(
            title: "Red", key: .red, dotTop: 0xF92D23, dotBottom: 0x9D0B01,
            stops: [(0xF92D23, 0), (0xCB1C12, 0.5), (0xB4140A, 0.75), (0x9D0B01, 1)],
            centerY: 0.373, endX: 1.127
        ),
        ColourKey(
            title: "Yellow", key: .yellow, dotTop: 0xFCB613, dotBottom: 0xC77802,
            stops: [(0xFCB613, 0), (0xE2970B, 0.5), (0xC77802, 1)],
            centerY: 0.380, endX: 1.120
        ),
        ColourKey(
            title: "Green", key: .green, dotTop: 0x36CC3F, dotBottom: 0x096115,
            stops: [(0x36CC3F, 0), (0x1F962A, 0.5), (0x147C1F, 0.75), (0x096115, 1)],
            centerY: 0.394, endX: 1.106
        )
    ]
}
