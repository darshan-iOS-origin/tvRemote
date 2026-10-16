import UIKit

/// The round navigation pad: four arrows around a blue OK key, as in the Figma "Remote" frame.
final class RemoteDPadView: UIView {

    static let diameter: CGFloat = DeviceLayout.remote(180)
    private static let okDiscSize: CGFloat = DeviceLayout.remote(90)
    private static let okKeySize: CGFloat = DeviceLayout.remote(72)
    private static let arrowTouchSize: CGFloat = DeviceLayout.remote(44)
    /// Distance from the pad's edge to the centre of an arrow (2 pt border + 8 pt gap + half the 26 pt glyph).
    private static let arrowCenterInset: CGFloat = DeviceLayout.remote(23)

    private enum Edge { case left, right, top, bottom }

    /// Every key of the pad, so the screen can dim the ones the TV lacks.
    private(set) var keyButtons: [RemoteKeyButton] = []
    private let onKey: (KeyCommand) -> Void

    init(onKey: @escaping (KeyCommand) -> Void) {
        self.onKey = onKey
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter)
        ])
        addSurface()
        addArrows()
        addOKKey()
    }

    required init?(coder: NSCoder) {
        fatalError("RemoteDPadView is built in code")
    }

    private func addSurface() {
        let surface = UIView()
        surface.isUserInteractionEnabled = false
        surface.backgroundColor = RemoteTheme.box
        surface.clipsToBounds = true
        surface.layer.cornerRadius = Self.diameter / 2
        surface.layer.borderWidth = 2
        surface.layer.borderColor = RemoteTheme.dpadBorder.cgColor
        addSubview(surface)
        surface.pinEdges(to: self)

        // Two diagonal dividers cut the pad into four wedges. The second asset is turned 90° to run the other way.
        let dividers = [
            ("ic_remote_dpad_divider_a", CGAffineTransform.identity),
            ("ic_remote_dpad_divider_b", CGAffineTransform(rotationAngle: .pi / 2))
        ]
        for (name, transform) in dividers {
            let imageView = UIImageView(image: UIImage(named: name))
            imageView.isUserInteractionEnabled = false
            imageView.transform = transform
            imageView.translatesAutoresizingMaskIntoConstraints = false
            surface.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: surface.centerYAnchor)
            ])
        }
    }

    /// One chevron asset (pointing left), turned for each direction.
    private func addArrows() {
        let arrows: [(Edge, CGFloat, KeyCommand)] = [
            (.left, 0, .left),
            (.right, .pi, .right),
            (.top, .pi / 2, .up),
            (.bottom, -.pi / 2, .down)
        ]
        for (edge, angle, key) in arrows {
            let button = RemoteKeyButton(
                icon: .image("ic_remote_dpad_chevron", transform: CGAffineTransform(rotationAngle: angle)),
                fill: .clear,
                borderWidth: 0,
                width: Self.arrowTouchSize,
                height: Self.arrowTouchSize
            )
            button.bind(key, repeats: true, handler: onKey)
            keyButtons.append(button)
            addSubview(button)
            let inset = Self.arrowCenterInset
            switch edge {
            case .left:
                NSLayoutConstraint.activate([
                    button.centerXAnchor.constraint(equalTo: leadingAnchor, constant: inset),
                    button.centerYAnchor.constraint(equalTo: centerYAnchor)
                ])
            case .right:
                NSLayoutConstraint.activate([
                    button.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
                    button.centerYAnchor.constraint(equalTo: centerYAnchor)
                ])
            case .top:
                NSLayoutConstraint.activate([
                    button.centerXAnchor.constraint(equalTo: centerXAnchor),
                    button.centerYAnchor.constraint(equalTo: topAnchor, constant: inset)
                ])
            case .bottom:
                NSLayoutConstraint.activate([
                    button.centerXAnchor.constraint(equalTo: centerXAnchor),
                    button.centerYAnchor.constraint(equalTo: bottomAnchor, constant: -inset)
                ])
            }
        }
    }

    private func addOKKey() {
        let disc = UIView()
        disc.isUserInteractionEnabled = false
        disc.backgroundColor = RemoteTheme.dpadCenter
        disc.layer.cornerRadius = Self.okDiscSize / 2
        disc.translatesAutoresizingMaskIntoConstraints = false
        addSubview(disc)

        let ok = RemoteKeyButton(
            title: "OK",
            font: CommonFont.bold.font(ofSize: 24),
            fill: .linear(top: RemoteTheme.blueTop, bottom: RemoteTheme.blueBottom),
            borderColor: UIColor.white.withAlphaComponent(0.1),
            borderWidth: 1.5,
            shadowed: true,
            width: Self.okKeySize,
            height: Self.okKeySize
        )
        ok.bind(.select, handler: onKey)
        keyButtons.append(ok)
        addSubview(ok)

        NSLayoutConstraint.activate([
            disc.centerXAnchor.constraint(equalTo: centerXAnchor),
            disc.centerYAnchor.constraint(equalTo: centerYAnchor),
            disc.widthAnchor.constraint(equalToConstant: Self.okDiscSize),
            disc.heightAnchor.constraint(equalToConstant: Self.okDiscSize),
            ok.centerXAnchor.constraint(equalTo: centerXAnchor),
            ok.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
