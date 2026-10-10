import UIKit

/// iPad-only layout values. Anything that should look different on iPad checks `isPad` and uses these, so the
/// iPhone layout stays as it is and the numbers can be tuned in one place.
enum DeviceLayout {

    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Height of a primary (blue Lottie) button on iPad. iPhone keeps 60 pt (`LottieManager.buttonHeight`).
    static let padButtonHeight: CGFloat = 84

    /// The widest the blue pill of a primary button is on iPad. The button itself stays as wide as before (touch
    /// area, title), but the pill is drawn at most this wide, centred.
    static let padButtonMaxWidth: CGFloat = 480

    /// Gap between the button's edge and the blue pill of its animation on iPad. 0 makes the pill fill the button
    /// completely (the pulsing ring is then clipped away); a few points leave room for the ring to show.
    static let padButtonPillInset: CGFloat = 4

    /// Every font in the app is this many times bigger on iPad (1 on iPhone). `CommonFont` applies it, and
    /// `UIViewController.scalePadFonts()` applies it to the text set in the storyboard.
    static var padFontScale: CGFloat { isPad ? 1.2 : 1 }

    /// The widest the brand grid on the last onboarding page is on iPad.
    static let padBrandGridMaxWidth: CGFloat = 560
}
