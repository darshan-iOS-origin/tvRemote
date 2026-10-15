import UIKit

/// The panel under the cast options: a status line with a spinner, the player keys (previous, play or
/// pause, next, stop). Errors are not shown here: the screen uses the standard iOS alert. It reports taps
/// through closures and holds no casting logic.
final class CastNowPlayingView: UIView {

    var onPrevious: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onStop: (() -> Void)?
    /// The user started or ended a drag on the bar.
    var onScrubbing: ((Bool) -> Void)?
    /// The user let go of the bar at this many seconds.
    var onSeek: ((TimeInterval) -> Void)?

    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let controls = UIStackView()
    private let slider = UISlider()
    private let elapsedLabel = UILabel()
    private let totalLabel = UILabel()
    private let timeRow = UIStackView()
    private var duration: TimeInterval = 0
    private var isDragging = false
    private let previousButton = CastNowPlayingView.makeKey(symbol: "backward.end.fill", label: "Previous")
    private let playPauseButton = CastNowPlayingView.makeKey(symbol: "pause.fill", label: "Pause")
    private let nextButton = CastNowPlayingView.makeKey(symbol: "forward.end.fill", label: "Next")
    private let stopButton = CastNowPlayingView.makeKey(symbol: "stop.fill", label: "Stop")

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        render(.idle)
    }

    required init?(coder: NSCoder) {
        fatalError("CastNowPlayingView is built in code")
    }

    func render(_ state: CastController.State) {
        switch state {
        case .idle:
            isHidden = true
        case .busy(let text):
            isHidden = false
            spinner.startAnimating()
            statusLabel.text = text
            controls.isHidden = true
            timeRow.isHidden = true
            slider.isHidden = true
        case .playing(let index, let count, let kind, let isPaused):
            isHidden = false
            spinner.stopAnimating()
            controls.isHidden = false
            previousButton.isEnabled = index > 0
            nextButton.isEnabled = index < count - 1
            playPauseButton.setImage(UIImage(systemName: isPaused ? "play.fill" : "pause.fill"), for: .normal)
            playPauseButton.accessibilityLabel = isPaused ? "Play" : "Pause"
            statusLabel.text = "\(isPaused ? "Paused" : "Casting"): \(Self.name(of: kind)) \(index + 1) of \(count)"
        case .failed:
            // The screen shows the failure in an alert; there is nothing to play.
            isHidden = true
            spinner.stopAnimating()
        }
    }

    /// Shows the position, or hides the bar when the TV can't report one. Ignored while the user is dragging.
    func render(progress: CastProgress?) {
        guard let progress, progress.duration > 0 else {
            slider.isHidden = true
            timeRow.isHidden = true
            return
        }
        slider.isHidden = false
        timeRow.isHidden = false
        guard !isDragging else { return }
        duration = progress.duration
        slider.value = Float(progress.position / progress.duration)
        elapsedLabel.text = Self.format(progress.position)
        totalLabel.text = Self.format(progress.duration)
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.rounded()))
        let h = total / 3600, m = (total / 60) % 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    @objc private func sliderBegan() {
        isDragging = true
        onScrubbing?(true)
    }

    @objc private func sliderChanged() {
        elapsedLabel.text = Self.format(TimeInterval(slider.value) * duration)
    }

    @objc private func sliderEnded() {
        isDragging = false
        onSeek?(TimeInterval(slider.value) * duration)
    }

    private static func name(of kind: CastMediaKind) -> String {
        switch kind {
        case .photo: return "Photo"
        case .video: return "Video"
        case .music: return "Song"
        }
    }

    // MARK: - Build

    private func build() {
        backgroundColor = UIColor(hex: 0x10182C)
        layer.cornerRadius = 16
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(hex: 0x434F68).cgColor

        statusLabel.font = CommonFont.bold.font(ofSize: 15)
        statusLabel.textColor = CommonColor.white.color
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        spinner.color = CommonColor.white.color
        spinner.hidesWhenStopped = true

        previousButton.addTarget(self, action: #selector(tapPrevious), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(tapPlayPause), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(tapNext), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(tapStop), for: .touchUpInside)
        [previousButton, playPauseButton, nextButton, stopButton].forEach(controls.addArrangedSubview)
        controls.axis = .horizontal
        controls.spacing = 15
        controls.distribution = .equalCentering

        slider.minimumTrackTintColor = CommonColor.white.color
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.25)
        slider.isHidden = true
        slider.accessibilityLabel = "Playback position"
        slider.addTarget(self, action: #selector(sliderBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        for label in [elapsedLabel, totalLabel] {
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(0.7)
            label.text = "0:00"
        }
        totalLabel.textAlignment = .right
        timeRow.addArrangedSubview(elapsedLabel)
        timeRow.addArrangedSubview(totalLabel)
        timeRow.distribution = .equalSpacing
        timeRow.isHidden = true

        let stack = UIStackView(arrangedSubviews: [spinner, statusLabel, slider, timeRow, controls])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    private static func makeKey(symbol: String, label: String) -> HapticButton {
        let button = HapticButton(type: .custom)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = CommonColor.white.color
        button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(hex: 0x434F68).cgColor
        button.accessibilityLabel = label
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        return button
    }

    @objc private func tapPrevious() { onPrevious?() }
    @objc private func tapPlayPause() { onPlayPause?() }
    @objc private func tapNext() { onNext?() }
    @objc private func tapStop() { onStop?() }
}
