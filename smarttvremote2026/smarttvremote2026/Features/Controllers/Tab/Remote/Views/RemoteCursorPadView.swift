import UIKit

/// The "LG Remote" face of the middle of the remote: a round pad with a blue disc holding an arrow.
/// Press and hold the disc and tilt the phone to move the TV's cursor (`MotionPointer`); a quick tap clicks.
/// It stays idle until `isActive` is set, so the screen can explain it first (`onActivateRequest`).
final class RemoteCursorPadView: UIView {

    static let diameter: CGFloat = RemoteDPadView.diameter
    private static let discSize: CGFloat = DeviceLayout.remote(90)
    /// A press shorter than this, with no tilt, counts as a click.
    private static let tapLimit: TimeInterval = 0.25

    /// Whether holding the disc moves the cursor. Off until the user has seen the how-to dialog.
    var isActive = false {
        didSet { if !isActive { stopMoving() } }
    }
    /// The user tapped the disc while the cursor was not active.
    var onActivateRequest: (() -> Void)?
    /// Whole points to move the cursor, right and down being positive.
    var onMove: ((Int, Int) -> Void)?
    var onClick: (() -> Void)?

    private let disc = RemoteGradientView()
    private let motion = MotionPointer()
    private var pressStart = Date()
    private var didMove = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("RemoteCursorPadView is built in code")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter)
        ])

        let surface = UIView()
        surface.isUserInteractionEnabled = false
        surface.backgroundColor = RemoteTheme.box
        surface.clipsToBounds = true
        surface.layer.cornerRadius = Self.diameter / 2
        surface.layer.borderWidth = 2
        surface.layer.borderColor = RemoteTheme.dpadBorder.cgColor
        addSubview(surface)
        surface.pinEdges(to: self)

        disc.isUserInteractionEnabled = true
        disc.setLinear(top: RemoteTheme.blueTop, bottom: RemoteTheme.blueBottom)
        disc.layer.cornerRadius = Self.discSize / 2
        disc.clipsToBounds = true
        disc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(disc)

        let arrow = UIImageView(image: UIImage(named: "arrow"))
        arrow.contentMode = .scaleAspectFit
        arrow.isUserInteractionEnabled = false
        arrow.translatesAutoresizingMaskIntoConstraints = false
        disc.addSubview(arrow)

        NSLayoutConstraint.activate([
            disc.centerXAnchor.constraint(equalTo: centerXAnchor),
            disc.centerYAnchor.constraint(equalTo: centerYAnchor),
            disc.widthAnchor.constraint(equalToConstant: Self.discSize),
            disc.heightAnchor.constraint(equalToConstant: Self.discSize),
            arrow.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            arrow.centerYAnchor.constraint(equalTo: disc.centerYAnchor)
        ])

        // Zero hold time: it fires on touch-down, so the tilt starts the moment the finger lands.
        let press = UILongPressGestureRecognizer(target: self, action: #selector(onPress(_:)))
        press.minimumPressDuration = 0
        disc.addGestureRecognizer(press)

        disc.isAccessibilityElement = true
        disc.accessibilityLabel = "Magic cursor"
        disc.accessibilityTraits = .button

        motion.onMove = { [weak self] dx, dy in
            MainActor.assumeIsolated {
                self?.didMove = true
                self?.onMove?(dx, dy)
            }
        }
    }

    deinit {
        motion.stop()
    }

    /// Stops the cursor and makes the next tap show the how-to dialog again.
    func deactivate() {
        isActive = false
    }

    private func stopMoving() {
        motion.stop()
    }

    @objc private func onPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            pressStart = Date()
            didMove = false
            if isActive { motion.start() }
        case .ended:
            motion.stop()
            if !isActive {
                onActivateRequest?()
            } else if !didMove, Date().timeIntervalSince(pressStart) < Self.tapLimit {
                onClick?()
            }
        case .cancelled, .failed:
            motion.stop()
        default:
            break
        }
    }
}
