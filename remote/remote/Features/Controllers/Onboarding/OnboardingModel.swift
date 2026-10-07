import UIKit

struct OnboardingPage {
    let background: String
    let icon: String
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
}
