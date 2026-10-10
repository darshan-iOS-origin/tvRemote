import UIKit

/// iPad-only layout values. Anything that should look different on iPad checks `isPad` and uses these, so the
/// iPhone layout stays as it is and the numbers can be tuned in one place.
enum DeviceLayout {

    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Height of a primary (blue Lottie) button on iPad. iPhone keeps 60 pt (`LottieManager.buttonHeight`).
    static let padButtonHeight: CGFloat = 84

    /// Gap between the button's edge and the blue pill of its animation on iPad. 0 makes the pill fill the button
    /// completely (the pulsing ring is then clipped away); a few points leave room for the ring to show.
    static let padButtonPillInset: CGFloat = 4

    /// Added to a Lottie button's title font size on iPad.
    static let padButtonFontBoost: CGFloat = 4

    /// Added to the onboarding title and description font sizes on iPad.
    static let padTextBoost: CGFloat = 6

    /// The widest the brand grid on the last onboarding page is on iPad.
    static let padBrandGridMaxWidth: CGFloat = 560
}
