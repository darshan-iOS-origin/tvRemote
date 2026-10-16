import UIKit

/// iPad-only layout values. Anything that should look different on iPad checks `isPad` and uses these, so the
/// iPhone layout stays as it is and the numbers can be tuned in one place.
enum DeviceLayout {

    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Height of a primary (blue Lottie) button on iPad. iPhone keeps 60 pt (`LottieManager.buttonHeight`).
    static let padButtonHeight: CGFloat = 84

    /// iPad: the general size of list rows, cards, icons and dialogs is this many times bigger than the iPhone design.
    /// Use `s(_:)` for a design size in points (iPhone: unchanged).
    static let padScale: CGFloat = 1.2
    static func s(_ value: CGFloat) -> CGFloat { isPad ? value * padScale : value }

    /// iPad, Remote tab: the keys, the d-pad, the touchpad, the VOL/CH pills and the spacing between them are this many
    /// times bigger. Use `remote(_:)` for a design size in points.
    static let padRemoteScale: CGFloat = 1.25
    static func remote(_ value: CGFloat) -> CGFloat { isPad ? value * padRemoteScale : value }

    /// iPad, Subscription screen: its text, icons and spacing are this many times bigger than the iPhone design, on
    /// top of `padFontScale` for text. The content column is at most `padSubscriptionColumnWidth` wide, centred.
    static let padSubscriptionScale: CGFloat = 1.2
    static let padSubscriptionColumnWidth: CGFloat = 640

    /// iPad: the plan cards (Monthly / Yearly) are this many times bigger (sizes, text, tab, ribbon).
    static let padPlanCardScale: CGFloat = 1.2

    /// iPad, Settings: everything is bigger. Space at the left and right of the content, between the sections, the
    /// gap between a section title and its card, the card corner radius, and the size of one row (iPhone: 16 / 24 / 12 / 20 / 58).
    static let padSettingsSideMargin: CGFloat = 32
    static let padSettingsSectionSpacing: CGFloat = 36
    static let padSettingsHeaderSpacing: CGFloat = 16
    static let padSettingsCardRadius: CGFloat = 28
    static let padSettingsRowHeight: CGFloat = 80
    /// Row icon size, the inside space at the left/right of a row, and the row title size (before `padFontScale`).
    static let padSettingsIconSize: CGFloat = 40
    static let padSettingsRowPadding: CGFloat = 26
    static let padSettingsRowFontSize: CGFloat = 18
    static let padSettingsHeaderFontSize: CGFloat = 18

    /// iPad, Remote tab: extra space at the left and right of the keys, sections and segment control (iPhone: none).
    static let padRemoteSideInset: CGFloat = 40

    /// iPad, Keyboard tab: the number pad is bigger. Largest key size in points (iPhone: 80); smaller iPads shrink it to fit.
    static let padKeypadMaxKeySize: CGFloat = 130

    /// iPad, Keyboard tab: key digit size (before `padFontScale`; iPhone: 26) - about a third of the key.
    static let padKeypadKeyFontSize: CGFloat = 36

    /// iPad, Keyboard tab: the big number above the pad (before `padFontScale`; iPhone: 50) and the room it gets.
    static let padKeypadDisplayFontSize: CGFloat = 88
    static let padKeypadDisplayHeight: CGFloat = 124

    /// iPad, App Theme: the grid of themes is at most this wide, centred (the two columns share it).
    static let padThemeGridMaxWidth: CGFloat = 520

    /// iPad, Settings: height of the PRO banner when the iPad picture `iapbanner_ipad` is in the asset catalog. It is
    /// then as wide as the cards. Design it 2048 x 240 px (1024 x 120 pt @2x).
    static let padProBannerHeight: CGFloat = 120

    /// iPad, Settings, while `iapbanner_ipad` is not added yet: the tallest the phone banner can be (it is 90:353
    /// wide-to-tall, so it would be ~180 pt tall).
    static let padProBannerMaxHeight: CGFloat = 110

    /// The asset name of the iPad PRO banner.
    static let padProBannerImageName = "iapbanner_ipad"

    /// iPad, Free Trial: the timeline card (the three steps) is at most this wide, centred.
    static let padTimelineMaxWidth: CGFloat = 520

    /// iPad, Free Trial: extra size for the three timeline steps, on top of `padFontScale`.
    static let padTimelineFontScale: CGFloat = 1.25

    /// iPad, Subscription and Free Trial screens: the two plan cards together are at most this wide, centred.
    static let padPlansMaxWidth: CGFloat = 560

    /// iPad, Subscription and Free Trial screens: height of the blue button there (shorter than the 84 pt of
    /// `padButtonHeight`, so the animation is not cut).
    static let padSubscriptionButtonHeight: CGFloat = 64

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
