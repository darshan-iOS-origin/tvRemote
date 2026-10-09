import Foundation

/// The subscription products and the RevenueCat entitlement, in one place. The product IDs must match
/// App Store Connect and the RevenueCat dashboard exactly; change them here only.
enum SubscriptionProduct: String, CaseIterable {

    case monthly = "com.tvremote.universal.smartcontrol.monthly"
    case yearly = "com.tvremote.universal.smartcontrol.year"
    /// The discounted yearly plan, offered when the Subscription screen is closed.
    case yearlyOffer = "com.tvremote.universal.smartcontrol.year.offer"

    /// The RevenueCat entitlement the three products unlock. A user is Premium while it is active.
    static let entitlementID = "Pro Access"

    static var allIDs: Set<String> {
        Set(allCases.map(\.rawValue))
    }

    /// Plan name for the cards and the log.
    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .yearlyOffer: return "Yearly Offer"
        }
    }

    /// Days in one billing period, for the "per day" price (30 and 365 are close enough for a label).
    var daysPerPeriod: Int {
        switch self {
        case .monthly: return 30
        case .yearly, .yearlyOffer: return 365
        }
    }
}
