import UIKit

struct OnboardingPage {
    let background: String
    let icon: String

    /// The picture to show: iPad has its own, wider pictures named `<background>_ipad` (`ob_1_ipad`, `ob_2_ipad`).
    var backgroundName: String {
        DeviceLayout.isPad ? "\(background)_ipad" : background
    }
    let title: String
    let description: String

    static let all: [OnboardingPage] = [
        OnboardingPage(
            background: "ob_1",
            icon: "ob_ic_1",
            title: "Remote Control",
            description: "Control your smart TV Directly form your\nphone with full functionality!"
        ),
        OnboardingPage(
            background: "ob_2",
            icon: "ob_ic_2",
            title: "Favorites Channels",
            description: "Save your favorite channels for quick &\neasy access."
        )
    ]

    /// Copy for the last onboarding page, where the user picks a TV brand.
    static let brandTitle = "Select Your TV Brand"
    static let brandDescription = "Choose your TV Brand to set up & connect"
}

struct BrandOption {
    let brand: TVBrand
    let imageName: String

    /// Tells tiles apart when two of them share a brand (the combined "Fire TV / Android TV" tile and "Fire TV").
    var id: String { imageName }

    static let all: [BrandOption] = [
        BrandOption(brand: .roku, imageName: "roku"),
        BrandOption(brand: .samsung, imageName: "samsung"),
        BrandOption(brand: .lg, imageName: "lg"),
        BrandOption(brand: .sony, imageName: "sony"),
        BrandOption(brand: .vizio, imageName: "vizio"),
        BrandOption(brand: .fireTV, imageName: "firetvGoogle"),
        BrandOption(brand: .fireTV, imageName: "fire"),
        BrandOption(brand: .other, imageName: "other")
    ]
}
