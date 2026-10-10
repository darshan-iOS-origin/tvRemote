import UIKit

/// "Unlock Custom Icons": a bottom sheet over a dimmed screen. The `appiconBanner` picture straddles the
/// sheet's curved top edge, with the title, a line of text and a "Go Premium" button below it. The sheet has a
/// top-to-bottom gradient (#111E41 into #000312).
///
/// Closes when the backdrop is tapped or the sheet is swiped down. "Go Premium" closes it and opens the
/// Subscription screen over the screen it was shown on (`onGoPremium` replaces that).
final class AppIconSheetVC: UIViewController {

    /// Runs after the sheet has gone away, when the user taps Go Premium. Default: the Subscription screen.
    var onGoPremium: (() -> Void)?

    /// Set once the sheet has been shown, so `presentOnceIfFree` shows it once per app launch.
    private static var hasShownThisLaunch = false

    private static let blue = UIColor(hex: 0x004BF9)
    private static let muted = UIColor(hex: 0x707A91)
    private static let glow = UIColor(hex: 0x111E41)
    private static let base = UIColor(hex: 0x000312)

    /// The banner is 340×253 pt; it takes this share of the screen width.
    private static let bannerWidthShare: CGFloat = 0.78
    private static let bannerAspect: CGFloat = 253.3 / 340.0
    /// How much of the banner's height sticks out above the sheet's top edge.
    private static let bannerOutsideShare: CGFloat = 0.46

    private let backdropView = UIView()
    /// Holds the sheet and the banner, so both move together when the sheet slides or is dragged. Touches on
    /// its empty parts go through to the backdrop (a tap there closes the sheet).
    private let contentView = PassthroughView()
    private let sheetView = GradientSheetView()
    private let bannerView = UIImageView(image: UIImage(named: "appiconBanner"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let premiumButton = HapticButton(type: .custom)
    private var sheetTopOffset: NSLayoutConstraint?
    private var isClosing = false

    // MARK: - Showing

    /// Shows the sheet over `host` for a free user, once per app launch. Nothing happens for a Premium user,
    /// when it has already been shown, or while something else is presented.
    static func presentOnceIfFree(from host: UIViewController) {
        guard !SubscriptionManager.shared.isPremium, !hasShownThisLaunch,
              host.presentedViewController == nil, host.view.window != nil else { return }
        hasShownThisLaunch = true
        host.present(AppIconSheetVC(), animated: true)
    }

    /// Shows the sheet over `host` every time, for a free user (a tap on a Premium action, such as Apply).
    /// Nothing happens for a Premium user, or while something else is presented.
    static func presentIfFree(from host: UIViewController) {
        guard !SubscriptionManager.shared.isPremium, host.presentedViewController == nil,
              host.view.window != nil else { return }
        hasShownThisLaunch = true
        host.present(AppIconSheetVC(), animated: true)
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityViewIsModal = true
        buildBackdrop()
        buildSheet()
        // Starts below the screen; `viewDidAppear` slides it up.
        if !UIAccessibility.isReduceMotionEnabled {
            contentView.transform = CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.height)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
        guard contentView.transform != .identity else { return }
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
            self.contentView.transform = .identity
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The sheet's top edge is a fixed share of the banner's height below the banner's top.
        let offset = bannerView.bounds.height * Self.bannerOutsideShare
        if let sheetTopOffset, abs(sheetTopOffset.constant - offset) > 0.5 {
            sheetTopOffset.constant = offset
        }
    }

    // MARK: - Layout

    private func buildBackdrop() {
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        backdropView.isAccessibilityElement = true
        backdropView.accessibilityLabel = "Close"
        backdropView.accessibilityTraits = .button
        backdropView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap_backdrop)))
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdropView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func buildSheet() {
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        // Anywhere on the sheet or the banner: touches on them have `contentView` as an ancestor.
        contentView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onPan_sheet(_:))))
        contentView.addSubview(sheetView)

        bannerView.contentMode = .scaleAspectFit
        bannerView.isAccessibilityElement = false
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        // Above the sheet in the stacking order, so the half inside the sheet is drawn over its gradient.
        contentView.addSubview(bannerView)

        titleLabel.text = "Unlock Custom Icons"
        titleLabel.font = CommonFont.bold.font(ofSize: 22)
        titleLabel.textColor = CommonColor.white.color
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        subtitleLabel.text = "Choose from a collection of custom icons & give your app a fresh new look."
        subtitleLabel.font = CommonFont.regular.font(ofSize: 14)
        subtitleLabel.textColor = Self.muted
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        premiumButton.setTitle("Go Premium", for: .normal)
        premiumButton.setTitleColor(CommonColor.white.color, for: .normal)
        premiumButton.titleLabel?.font = CommonFont.bold.font(ofSize: 20)
        premiumButton.backgroundColor = Self.blue
        premiumButton.hapticType = .medium
        premiumButton.addTarget(self, action: #selector(onTap_premium), for: .touchUpInside)
        LottieManager.applyButtonBackground(to: premiumButton)

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, premiumButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(28, after: subtitleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        let topOffset = sheetView.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 0)
        sheetTopOffset = topOffset
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            bannerView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: Self.bannerWidthShare),
            bannerView.heightAnchor.constraint(equalTo: bannerView.widthAnchor, multiplier: Self.bannerAspect),

            topOffset,
            sheetView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sheetView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            sheetView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stack.topAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12)
        ])
    }

    // MARK: - Actions

    @objc private func onTap_backdrop() {
        close(then: nil)
    }

    @objc private func onTap_premium() {
        let presenter = presentingViewController
        close { [onGoPremium] in
            if let onGoPremium {
                onGoPremium()
            } else if let presenter {
                NavigationManager.shared.showSubscription(from: presenter)
            }
        }
    }

    /// Swipe the sheet down to close it; let go early or slowly and it springs back.
    @objc private func onPan_sheet(_ gesture: UIPanGestureRecognizer) {
        let travel = max(gesture.translation(in: view).y, 0)
        switch gesture.state {
        case .changed:
            contentView.transform = CGAffineTransform(translationX: 0, y: travel)
        case .ended, .cancelled:
            let flick = gesture.velocity(in: view).y > 900
            if travel > 120 || flick {
                close(then: nil)
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
                    self.contentView.transform = .identity
                }
            }
        default:
            break
        }
    }

    /// Slides the sheet down (or fades, with Reduce Motion), then dismisses the screen and runs `then`.
    private func close(then completion: (() -> Void)?) {
        guard !isClosing else { return }
        isClosing = true
        let animations = {
            if UIAccessibility.isReduceMotionEnabled {
                self.contentView.alpha = 0
            } else {
                self.contentView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            }
            self.backdropView.alpha = 0
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: animations) { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }
}

/// A view that is not hit itself, only its subviews are: a touch on its empty parts reaches what is behind it.
private final class PassthroughView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

/// The sheet: rounded top corners and a top-to-bottom gradient from #111E41 into #000312.
private final class GradientSheetView: UIView {

    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        guard let gradient = layer as? CAGradientLayer else { return }
        gradient.colors = [UIColor(hex: 0x111E41).cgColor, UIColor(hex: 0x000312).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.cornerRadius = 32
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("GradientSheetView is built in code")
    }
}
