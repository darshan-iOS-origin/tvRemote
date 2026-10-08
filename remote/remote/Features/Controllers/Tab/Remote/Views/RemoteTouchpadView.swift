import UIKit

/// The touchpad shown instead of the d-pad: swipe to move around the TV's menus, tap for OK.
/// Swipes become arrow keys, so it works on every TV the d-pad works on.
final class RemoteTouchpadView: UIView {

    static let size: CGFloat = 180
    private static let cornerRadius: CGFloat = 28
    /// How far a finger travels along one axis for each key that is sent.
    private static let stepDistance: CGFloat = 36

    // Position of the dotted grooves behind the label, from the Figma frame.
    private static let grooveCount = 19
    private static let groovePitch: CGFloat = 8.563
    private static let grooveOrigin = CGPoint(x: 12, y: 20)

    private let onKey: (KeyCommand) -> Void
    /// Distance travelled since the last key, per axis.
    private var travelled = CGPoint.zero
    private var lastTranslation = CGPoint.zero

    init(onKey: @escaping (KeyCommand) -> Void) {
        self.onKey = onKey
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size),
            heightAnchor.constraint(equalToConstant: Self.size)
        ])
        buildSurface()
        buildGrooves()
        buildIcon()
        buildLabel()
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onPan(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap_pad)))
    }

    required init?(coder: NSCoder) {
        fatalError("RemoteTouchpadView is built in code")
    }

    // MARK: - Building

    private var surface: UIView { subviews[0] }

    private func buildSurface() {
        let surface = UIView()
        surface.isUserInteractionEnabled = false
        surface.backgroundColor = RemoteTheme.box
        surface.clipsToBounds = true
        surface.layer.cornerRadius = Self.cornerRadius
        surface.layer.borderWidth = 2
        surface.layer.borderColor = RemoteTheme.dpadBorder.cgColor
        addSubview(surface)
        surface.pinEdges(to: self)
    }

    private func buildGrooves() {
        let image = UIImage(named: "ic_remote_touchpad_groove")
        for index in 0..<Self.grooveCount {
            let groove = UIImageView(image: image)
            groove.isUserInteractionEnabled = false
            groove.frame.origin = CGPoint(
                x: Self.grooveOrigin.x + CGFloat(index) * Self.groovePitch,
                y: Self.grooveOrigin.y
            )
            surface.addSubview(groove)
        }
    }

    /// The hand icon in the middle of the pad.
    private func buildIcon() {
        let icon = UIImageView(image: UIImage(named: "ic_touch_pad_fill"))
        icon.isUserInteractionEnabled = false
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func buildLabel() {
        let label = UILabel()
        label.isUserInteractionEnabled = false
        label.attributedText = NSAttributedString(string: "Swipe to navigate", attributes: [
            .font: CommonFont.medium.font(ofSize: 14),
            .foregroundColor: CommonColor.secondaryGray.color,
            .kern: 0.28
        ])
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            // Under the icon, which is centred in the pad.
            label.topAnchor.constraint(equalTo: centerYAnchor, constant: 44)
        ])
    }

    // MARK: - Gestures

    @objc private func onTap_pad() {
        HapticManager.trigger(.light)
        onKey(.select)
    }

    /// Sends an arrow key for every `stepDistance` points of travel, so a long swipe keeps moving.
    @objc private func onPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            travelled = .zero
            lastTranslation = .zero
        case .changed:
            let translation = gesture.translation(in: self)
            travelled.x += translation.x - lastTranslation.x
            travelled.y += translation.y - lastTranslation.y
            lastTranslation = translation
            emitKeys()
        default:
            break
        }
    }

    /// Moves along the axis the finger has gone furthest on, and drops the other axis's leftover.
    private func emitKeys() {
        let step = Self.stepDistance
        if abs(travelled.x) >= abs(travelled.y) {
            while abs(travelled.x) >= step {
                send(travelled.x > 0 ? .right : .left)
                travelled.x -= step * (travelled.x > 0 ? 1 : -1)
                travelled.y = 0
            }
        } else {
            while abs(travelled.y) >= step {
                send(travelled.y > 0 ? .down : .up)
                travelled.y -= step * (travelled.y > 0 ? 1 : -1)
                travelled.x = 0
            }
        }
    }

    private func send(_ key: KeyCommand) {
        HapticManager.trigger(.light)
        onKey(key)
    }
}
