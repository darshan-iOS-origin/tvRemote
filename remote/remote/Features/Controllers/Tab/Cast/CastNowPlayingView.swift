import AVFoundation
import UIKit

/// A view that draws an `AVPlayer`'s video, fitted inside (the whole picture, nothing cropped).
private final class CastPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

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

    private let previewView = UIImageView()
    private let previewIcon = UIImageView()
    private let previewHolder = UIView()
    private let statusLabel = UILabel()
    /// The loader sits on the preview, so the panel does not change size while a new item loads.
    private let spinner = UIActivityIndicatorView(style: .large)
    private let playerView = CastPlayerView()
    private let player = AVPlayer()
    private var playerURL: URL?
    private var isVideoPreview = false
    private var timeObserver: Any?
    /// True while the TV is reporting its position; the phone's own player is then only pulled along by it.
    private var tvReportsProgress = false
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

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
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
            previewHolder.isHidden = false
            spinner.startAnimating()
            if controls.isHidden {
                // First load: nothing is playing yet.
                statusLabel.text = text
            } else {
                // Moving to another item: the panel keeps its layout and only the keys pause for a moment.
                controls.isUserInteractionEnabled = false
                slider.isUserInteractionEnabled = false
                player.pause()
            }
        case .playing(let index, let count, let kind, let isPaused):
            isHidden = false
            spinner.stopAnimating()
            controls.isUserInteractionEnabled = true
            slider.isUserInteractionEnabled = true
            controls.isHidden = false
            if isVideoPreview {
                if isPaused { player.pause() } else { player.play() }
            }
            previousButton.isEnabled = index > 0
            nextButton.isEnabled = index < count - 1
            playPauseButton.setImage(UIImage(systemName: isPaused ? "play.fill" : "pause.fill"), for: .normal)
            playPauseButton.accessibilityLabel = isPaused ? "Play" : "Pause"
            statusLabel.text = "\(isPaused ? "Paused" : "Casting"): \(Self.name(of: kind)) \(index + 1) of \(count)"
        case .failed:
            // The screen shows the failure in an alert; there is nothing to play.
            isHidden = true
            spinner.stopAnimating()
            player.pause()
        }
    }

    /// Shows what is being cast: a photo, the video in a small player (muted, kept in step with the TV), or an
    /// icon for music. The previous picture stays until the next one is ready, so changing items does not blink.
    /// `media` nil clears it.
    func render(preview media: CastMedia?, image: CGImage?) {
        guard let media else {
            previewHolder.isHidden = true
            previewView.image = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
            playerURL = nil
            isVideoPreview = false
            return
        }
        previewHolder.isHidden = false
        isVideoPreview = media.kind == .video
        playerView.isHidden = !isVideoPreview
        if isVideoPreview {
            previewView.isHidden = true
            previewIcon.isHidden = true
            if playerURL != media.fileURL {
                playerURL = media.fileURL
                player.replaceCurrentItem(with: AVPlayerItem(url: media.fileURL))
            }
            return
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        playerURL = nil
        if let image {
            previewIcon.isHidden = true
            previewView.isHidden = false
            UIView.transition(with: previewView, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.previewView.image = UIImage(cgImage: image)
            }
        } else {
            previewView.isHidden = true
            previewView.image = nil
            previewIcon.isHidden = false
            previewIcon.image = UIImage(systemName: media.kind == .music ? "music.note" : "photo")
        }
    }

    /// Shows the position, or hides the bar when the TV can't report one. Ignored while the user is dragging.
    func render(progress: CastProgress?) {
        guard let progress, progress.duration > 0 else {
            tvReportsProgress = false
            // Without the TV's position a video still has one: the preview player's (see `followPlayer`).
            if !isVideoPreview {
                slider.isHidden = true
                timeRow.isHidden = true
            }
            return
        }
        tvReportsProgress = true
        slider.isHidden = false
        timeRow.isHidden = false
        guard !isDragging else { return }
        // Keep the phone's picture on the TV's position: a jump (seek, or the TV buffering) pulls it along.
        if isVideoPreview, abs(player.currentTime().seconds - progress.position) > 1.5 {
            player.seek(to: CMTime(seconds: progress.position, preferredTimescale: 600))
        }
        show(position: progress.position, duration: progress.duration)
    }

    private func show(position: TimeInterval, duration: TimeInterval) {
        self.duration = duration
        slider.value = Float(min(max(position / duration, 0), 1))
        elapsedLabel.text = Self.format(position)
        totalLabel.text = Self.format(duration)
    }

    /// Moves the bar with the preview video, between the TV's once-a-second reports (and on its own when the TV
    /// reports nothing).
    private func followPlayer() {
        guard isVideoPreview, !isDragging, let item = player.currentItem else { return }
        let length = item.duration.seconds
        guard length.isFinite, length > 0 else { return }
        slider.isHidden = false
        timeRow.isHidden = false
        show(position: player.currentTime().seconds, duration: length)
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
        let target = TimeInterval(slider.value) * duration
        if isVideoPreview { player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) }
        onSeek?(target)
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
        spinner.translatesAutoresizingMaskIntoConstraints = false
        player.isMuted = true
        player.actionAtItemEnd = .pause
        playerView.playerLayer.player = player
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor in self?.followPlayer() }
        }
        playerView.playerLayer.videoGravity = .resizeAspect
        playerView.isHidden = true

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

        previewHolder.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        previewHolder.layer.cornerRadius = 12
        previewHolder.clipsToBounds = true
        previewHolder.isHidden = true
        previewHolder.isAccessibilityElement = true
        previewHolder.accessibilityLabel = "Preview of what is casting"
        previewView.contentMode = .scaleAspectFit
        previewIcon.contentMode = .scaleAspectFit
        previewIcon.tintColor = UIColor.white.withAlphaComponent(0.6)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        previewHolder.addSubview(playerView)
        previewHolder.addSubview(spinner)
        for item in [previewView, previewIcon] {
            item.translatesAutoresizingMaskIntoConstraints = false
            previewHolder.addSubview(item)
        }
        previewHolder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewHolder.heightAnchor.constraint(equalToConstant: 200),
            playerView.topAnchor.constraint(equalTo: previewHolder.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: previewHolder.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: previewHolder.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: previewHolder.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: previewHolder.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: previewHolder.centerYAnchor),
            previewView.topAnchor.constraint(equalTo: previewHolder.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: previewHolder.bottomAnchor),
            previewView.leadingAnchor.constraint(equalTo: previewHolder.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: previewHolder.trailingAnchor),
            previewIcon.centerXAnchor.constraint(equalTo: previewHolder.centerXAnchor),
            previewIcon.centerYAnchor.constraint(equalTo: previewHolder.centerYAnchor),
            previewIcon.widthAnchor.constraint(equalToConstant: 48),
            previewIcon.heightAnchor.constraint(equalToConstant: 48)
        ])

        let stack = UIStackView(arrangedSubviews: [previewHolder, statusLabel, slider, timeRow, controls])
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
