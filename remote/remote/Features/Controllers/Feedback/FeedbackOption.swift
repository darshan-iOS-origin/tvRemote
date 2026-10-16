import Foundation

/// The reasons the user can tick on the Feedback screen.
enum FeedbackOption: String, CaseIterable {
    case notGood = "Not Good"
    case appCrashes = "App Crashes"
    case veryPoor = "Very Poor"
    case slowExperience = "Slow Experience"
    case tooDifficult = "Too Difficult"
    case excellent = "Excellent"
    case disappointing = "Disappointing"
    case other = "Other"
}
