import Foundation

/// The reasons the user can pick on the Manage Subscription screen. `rawValue` is the title shown on the row
/// and the reason written in the cancellation mail.
enum ManageSubscriptionOption: String, CaseIterable {
    case expensive = "Expensive"
    case appCrash = "App Crash"
    case featureNotWorking = "Feature Not Working"
    case cheaperAlternative = "Found a cheaper alternative"
    case tooComplicated = "Too complicated"
    case keepPlan = "Keep Current Plan"

    var subtitle: String {
        switch self {
        case .expensive: return "Full premium access"
        case .appCrash: return "Stable, bug-free experience"
        case .featureNotWorking: return "Not working as expected"
        case .cheaperAlternative: return "I found a better value"
        case .tooComplicated: return "It's difficult to use"
        case .keepPlan: return "I want to keep my plan"
        }
    }

    /// Image in the "manage subs" asset folder.
    var iconName: String {
        switch self {
        case .expensive: return "expensive"
        case .appCrash: return "crash"
        case .featureNotWorking: return "notworking"
        case .cheaperAlternative: return "alternate"
        case .tooComplicated: return "complicated"
        case .keepPlan: return "keep"
        }
    }
}
