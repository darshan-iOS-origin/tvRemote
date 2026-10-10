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

    /// Height of a button that has the animated background.
    static let buttonHeight: CGFloat = 60

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
            ? placeCappedButtonBackground(in: button)
            : place(.button, in: button, loop: .loop, contentMode: .scaleAspectFill, at: 0)
        guard let view = animation else {
            return nil
        }
        view.tag = tag
        button.backgroundColor = .clear
        button.clipsToBounds = true
        setHeight(of: button, to: buttonHeight)
        button.layer.cornerRadius = buttonHeight / 2
        if DeviceLayout.isPad, let font = button.titleLabel?.font {
            button.titleLabel?.font = font.withSize(font.pointSize + DeviceLayout.padButtonFontBoost)
        }
        return view
    }

    /// iPad: the button can be very wide, and stretching the animation over it crops it to a thin strip. Keep it at
    /// most `DeviceLayout.padButtonMaxWidth` wide, centred, with its own rounded ends; the button (touch area and
    /// title) stays as wide as before.
    private static func placeCappedButtonBackground(in button: UIButton) -> LottieAnimationView? {
        guard let view = makeView(.button, loop: .loop, contentMode: .scaleAspectFill) else { return nil }
        view.layer.cornerRadius = buttonHeight / 2
        view.layer.masksToBounds = true
        button.insertSubview(view, at: 0)
        let fillWidth = view.widthAnchor.constraint(equalTo: button.widthAnchor)
        fillWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: button.topAnchor),
            view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            view.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            view.widthAnchor.constraint(lessThanOrEqualToConstant: DeviceLayout.padButtonMaxWidth),
            view.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor),
            fillWidth
        ])
        view.play()
        return view
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
