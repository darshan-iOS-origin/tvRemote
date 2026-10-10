import UIKit

/// iPad-only layout values. Anything that should look different on iPad checks `isPad` and uses these, so the
/// iPhone layout stays as it is and the numbers can be tuned in one place.
enum DeviceLayout {

    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Height of a primary (blue Lottie) button on iPad. iPhone keeps 60 pt (`LottieManager.buttonHeight`).
    static let padButtonHeight: CGFloat = 84

    /// How the button animation is drawn on iPad. `.scaleToFill` shows the whole animation on the wide button;
    /// `.scaleAspectFill` (iPhone) would zoom in and crop its top and bottom.
    static let padButtonContentMode: UIView.ContentMode = .scaleToFill

    /// Added to a Lottie button's title font size on iPad.
    static let padButtonFontBoost: CGFloat = 4

    /// Added to the onboarding title and description font sizes on iPad.
    static let padTextBoost: CGFloat = 6

    /// The widest the brand grid on the last onboarding page is on iPad.
    static let padBrandGridMaxWidth: CGFloat = 560
}
