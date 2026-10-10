import Lottie
import UIKit

/// The Lottie files in `Helper/lotties`. The raw value is the file name without `.json`.
enum LottieAsset: String {
    /// Animated blue background for a primary button.
    case button
    /// The ring that shows while the app searches for TVs.
    case scanning
    /// The launch animation.
    case splash
}

/// Every Lottie animation in the app goes through here, so loading, looping and placing are done one way.
/// A missing or broken file never crashes: the calls return nil or do nothing, and the screen keeps its
/// plain look.
@MainActor
enum LottieManager {

    /// A ready-to-play view, or nil if the file can't be loaded.
    static func makeView(
        _ asset: LottieAsset,
        loop: LottieLoopMode = .loop,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) -> LottieAnimationView? {
        guard let animation = LottieAnimation.named(asset.rawValue) else {
            LoggerManager.warning("Lottie file \(asset.rawValue).json not found", category: "Lottie")
            return nil
        }
        let view = LottieAnimationView(animation: animation)
        view.loopMode = loop
        view.contentMode = contentMode
        view.backgroundBehavior = .pauseAndRestore
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    /// Fills `container` with the animation (all four edges at 0) and plays it. `completion` runs when a
    /// non-looping animation ends, with `true` if it played to the end.
    @discardableResult
    static func place(
        _ asset: LottieAsset,
        in container: UIView,
        loop: LottieLoopMode = .loop,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        at index: Int? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> LottieAnimationView? {
        guard let view = makeView(asset, loop: loop, contentMode: contentMode) else { return nil }
        if let index {
            container.insertSubview(view, at: index)
        } else {
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        view.play(completion: completion)
        return view
    }

    /// Height of a button that has the animated background (a little taller on iPad).
    static var buttonHeight: CGFloat { DeviceLayout.isPad ? DeviceLayout.padButtonHeight : 60 }

    /// Makes the button's blue background the looping `button` animation. It sits behind the title, is
    /// clipped to the button's corners and does not take touches. The button becomes `buttonHeight` tall
    /// with fully rounded ends. If the file can't be loaded the button keeps its plain look and size.
    @discardableResult
    static func applyButtonBackground(to button: UIButton) -> LottieAnimationView? {
        let tag = 0x4C_4F_54
        if let existing = button.viewWithTag(tag) as? LottieAnimationView {
            existing.play()
            return existing
        }
        let animation = DeviceLayout.isPad
            ? placePillFilled(in: button)
            : place(.button, in: button, loop: .loop, contentMode: .scaleAspectFill, at: 0)
        guard let view = animation else {
            return nil
        }
        view.tag = tag
        button.backgroundColor = .clear
        button.clipsToBounds = true
        setHeight(of: button, to: buttonHeight)
        button.layer.cornerRadius = buttonHeight / 2
        if DeviceLayout.isPad {
            // The title sits exactly in the middle of the button, and so of the pill: no stray insets or alignment.
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
            button.titleEdgeInsets = .zero
            button.imageEdgeInsets = .zero
            button.contentEdgeInsets = .zero
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.lineBreakMode = .byClipping
        }
        return view
    }

    /// iPad: the `button` animation is a 333 x 52 blue pill (centred a little off, at 183.25, 43) inside a 370 x 80
    /// picture, with a ring that pulses outward from it. Stretching the whole picture over a wide button makes the
    /// pill small inside the button with the ring showing as a dark outline. Instead the picture is sized so that the
    /// PILL fills the button (less a small inset, so the ring still shows around it); the rest is clipped by the
    /// button's rounded ends.
    private static func placePillFilled(in button: UIButton) -> LottieAnimationView? {
        guard let animationView = makeView(.button, loop: .loop, contentMode: .scaleToFill) else { return nil }
        let host = PillFilledHost(animationView: animationView)
        host.translatesAutoresizingMaskIntoConstraints = false
        host.isUserInteractionEnabled = false
        button.insertSubview(host, at: 0)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: button.topAnchor),
            host.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])
        animationView.play()
        return animationView
    }

    /// Changes the button's own height constraint if it has one (a storyboard button usually does), and adds
    /// one if not.
    private static func setHeight(of button: UIButton, to height: CGFloat) {
        let own = button.constraints.first { $0.firstItem === button && $0.firstAttribute == .height && $0.secondItem == nil }
        if let own {
            own.constant = height
        } else {
            button.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
    }
}

/// Holds the `button` animation and lays it out so its blue pill fills this view (see `placePillFilled`).
private final class PillFilledHost: UIView {

    /// The pill in the animation's own coordinates (the picture is 370 x 80).
    private static let compositionSize = CGSize(width: 370, height: 80)
    private static let pillSize = CGSize(width: 333, height: 52)
    private static let pillCenter = CGPoint(x: 185 - 1.75, y: 40 + 3)

    private let animationView: LottieAnimationView

    init(animationView: LottieAnimationView) {
        self.animationView = animationView
        super.init(frame: .zero)
        animationView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(animationView)
    }

    required init?(coder: NSCoder) {
        fatalError("PillFilledHost is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        var pill = bounds.insetBy(dx: DeviceLayout.padButtonPillInset, dy: DeviceLayout.padButtonPillInset)
        guard pill.width > 0, pill.height > 0 else { return }
        // Narrower than the button on a wide iPad screen: keep it centred.
        if pill.width > DeviceLayout.padButtonMaxWidth {
            pill = CGRect(x: pill.midX - DeviceLayout.padButtonMaxWidth / 2, y: pill.minY,
                          width: DeviceLayout.padButtonMaxWidth, height: pill.height)
        }
        let scaleX = pill.width / Self.pillSize.width
        let scaleY = pill.height / Self.pillSize.height
        animationView.frame = CGRect(
            x: pill.midX - Self.pillCenter.x * scaleX,
            y: pill.midY - Self.pillCenter.y * scaleY,
            width: Self.compositionSize.width * scaleX,
            height: Self.compositionSize.height * scaleY
        )
    }
}
