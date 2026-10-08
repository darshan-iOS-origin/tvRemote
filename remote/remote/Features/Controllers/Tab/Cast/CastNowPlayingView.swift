import UIKit

/// The panel under the cast options: a status line with a spinner, the player keys (previous, play or
/// pause, next, stop). Errors are not shown here: the screen uses the standard iOS alert. It reports taps
/// through closures and holds no casting logic.
final class CastNowPlayingView: UIView {

    var onPrevious: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onStop: (() -> Void)?

    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let controls = UIStackView()
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

        let stack = UIStackView(arrangedSubviews: [spinner, statusLabel, controls])
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
