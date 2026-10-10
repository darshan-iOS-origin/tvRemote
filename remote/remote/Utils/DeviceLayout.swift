import UIKit

/// iPad-only layout values. Anything that should look different on iPad checks `isPad` and uses these, so the
/// iPhone layout stays as it is and the numbers can be tuned in one place.
enum DeviceLayout {

    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// The widest a primary (blue Lottie) button is drawn on iPad. On a wider button the animation stays this wide,
    /// centred, so it is not stretched and cropped. About the same scale as on an iPhone.
    static let padButtonMaxWidth: CGFloat = 360

    /// Added to a Lottie button's title font size on iPad.
    static let padButtonFontBoost: CGFloat = 4

    /// Added to the onboarding title and description font sizes on iPad.
    static let padTextBoost: CGFloat = 6

    /// The widest the brand grid on the last onboarding page is on iPad.
    static let padBrandGridMaxWidth: CGFloat = 560

    /// How much of the onboarding picture's width, at each side, fades out on iPad (so its edges do not show).
    static let padImageEdgeFade: CGFloat = 0.12
}
