import UIKit

/// The Remote tab: the on-screen TV remote from the Figma "Remote" frame. A fixed header sits above a
/// scrolling stack of keys. The keys only give haptic feedback for now; they send nothing to the TV.
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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        applyGradientBackground()

        let header = buildHeader()
        buildScrollView(below: header)
        buildContent()
        glassButtons.forEach { $0.applyGlassStyle() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        glassButtons.forEach { $0.updateGlassFallbackCorners() }
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
        let cast = circleKey(icon: .image("ic_remote_cast"), size: 60)
        let voice = circleKey(icon: .image("ic_remote_voice"), size: 60)
        let copy = circleKey(icon: .image("ic_remote_copy", transform: CGAffineTransform(scaleX: -1, y: 1)), size: 60)
        return spacedRow([power, cast, voice, copy])
    }

    /// Volume on the left, the d-pad in the middle, channel on the right.
    private func makeCluster() -> UIView {
        let cluster = UIView()
        cluster.translatesAutoresizingMaskIntoConstraints = false

        let dpad = RemoteDPadView()
        let volume = RemoteRockerView(
            top: .image("ic_remote_vol_plus"),
            title: "VOL",
            bottom: .image("ic_remote_vol_minus")
        )
        // Both channel chevrons are drawn pointing sideways and turned a quarter turn: up and down.
        let rightAngle = CGAffineTransform(rotationAngle: .pi / 2)
        let channel = RemoteRockerView(
            top: .image("ic_remote_ch_up", transform: rightAngle),
            title: "CH",
            bottom: .image("ic_remote_ch_down", transform: rightAngle)
        )
        [dpad, volume, channel].forEach(cluster.addSubview)

        NSLayoutConstraint.activate([
            cluster.heightAnchor.constraint(equalToConstant: RemoteDPadView.diameter),
            dpad.centerXAnchor.constraint(equalTo: cluster.centerXAnchor),
            dpad.centerYAnchor.constraint(equalTo: cluster.centerYAnchor),
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
            circleKey(icon: .image("ic_remote_skip", transform: flip), size: 60, borderWidth: 1),
            circleKey(icon: .image("ic_remote_play"), size: 60, borderWidth: 1),
            circleKey(icon: .image("ic_remote_skip"), size: 60, borderWidth: 1),
            circleKey(icon: .image("ic_remote_stop"), size: 60, borderWidth: 1)
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
        let liveTV = RemoteKeyButton(title: "LIVE TV", font: font, cornerRadius: 15, height: 56)
        let input = RemoteKeyButton(title: "INPUT", font: font, cornerRadius: 15, height: 56)
        return equalRow([liveTV, input], spacing: 15)
    }

    private func makeNavigationRow() -> UIView {
        let names = ["ic_remote_nav_back", "ic_remote_nav_home", "ic_remote_nav_notes", "ic_remote_nav_info"]
        return spacedRow(names.map { circleKey(icon: .image($0), size: 72) })
    }

    /// The design repeats "HDMI 1" four times; the four ports are numbered here.
    private func makeInputRow() -> UIView {
        let font = CommonFont.medium.font(ofSize: 11)
        let keys = (1...4).map {
            cardKey(icon: .image("ic_remote_hdmi"), title: "HDMI \($0)", font: font, spacing: 10, height: 79)
        }
        return equalRow(keys, spacing: 13.5)
    }

    private func makePlaybackRow() -> UIView {
        let flip = CGAffineTransform(scaleX: -1, y: 1)
        let small = CommonFont.medium.font(ofSize: 11)
        let large = CommonFont.medium.font(ofSize: 12)
        let keys = [
            cardKey(icon: .image("ic_remote_rewind"), title: "Back Forward", font: large, spacing: 12, height: 81),
            cardKey(icon: .image("ic_remote_play"), title: "Play / Pause", font: small, spacing: 12, height: 81),
            cardKey(icon: .image("ic_remote_rewind", transform: flip), title: "Fast Forward", font: large, spacing: 12, height: 81)
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
                fill: .radial(colour.tint, opacity: 0.15)
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
        borderWidth: CGFloat = RemoteTheme.keyBorderWidth
    ) -> RemoteKeyButton {
        RemoteKeyButton(icon: icon, borderWidth: borderWidth, width: size, height: size)
    }

    private func cardKey(
        icon: RemoteKeyButton.Icon,
        title: String,
        font: UIFont,
        spacing: CGFloat,
        height: CGFloat,
        fill: RemoteKeyButton.Fill = .box
    ) -> RemoteKeyButton {
        RemoteKeyButton(
            icon: icon,
            title: title,
            font: font,
            layout: .iconAbove(spacing: spacing),
            fill: fill,
            cornerRadius: 17,
            height: height
        )
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
        /// Top and bottom of the round swatch.
        let dotTop: UInt32
        let dotBottom: UInt32
        /// The key's soft background tint (drawn at 15% opacity).
        let tint: RemoteGradientView.Radial

        init(
            title: String,
            dotTop: UInt32,
            dotBottom: UInt32,
            stops: [(color: UInt32, location: CGFloat)],
            centerY: CGFloat,
            endX: CGFloat
        ) {
            self.title = title
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
            title: "Blue", dotTop: 0x0169F1, dotBottom: 0x003090,
            stops: [(0x0169F1, 0), (0x014DC1, 0.5), (0x003090, 1)],
            centerY: 0.387, endX: 1.113
        ),
        ColourKey(
            title: "Red", dotTop: 0xF92D23, dotBottom: 0x9D0B01,
            stops: [(0xF92D23, 0), (0xCB1C12, 0.5), (0xB4140A, 0.75), (0x9D0B01, 1)],
            centerY: 0.373, endX: 1.127
        ),
        ColourKey(
            title: "Yellow", dotTop: 0xFCB613, dotBottom: 0xC77802,
            stops: [(0xFCB613, 0), (0xE2970B, 0.5), (0xC77802, 1)],
            centerY: 0.380, endX: 1.120
        ),
        ColourKey(
            title: "Green", dotTop: 0x36CC3F, dotBottom: 0x096115,
            stops: [(0x36CC3F, 0), (0x1F962A, 0.5), (0x147C1F, 0.75), (0x096115, 1)],
            centerY: 0.394, endX: 1.106
        )
    ]
}
