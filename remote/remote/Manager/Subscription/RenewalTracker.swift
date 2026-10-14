import Foundation
import RevenueCat

/// Analytics for a paid subscription after it started, named with the entry point that sold it and the plan:
/// `<entry>_<m|y>sub_<step>`, e.g. `setting_banner_msub_renewed`. A plan switch has no plan tag:
/// `<entry>_sub_to_year`. `m` is Monthly, `y` Yearly (including the yearly offer). Events carry no parameters.
///
/// Like `TrialTracker`, the app only sees a change when it opens: RevenueCat's customer info is read in
/// `SubscriptionManager.apply`, which calls `process`. Several renewals between two opens log one `renewed`.
/// The entry point is saved when the plan is bought (or handed over from the free trial that converted); a plan
/// the app did not see being bought logs without the entry: `msub_renewed`. Trials are `TrialTracker`'s.
enum RenewalTracker {

    enum Step: String {
        /// A paid period renewed.
        case renewed
        /// The first renewal after the purchase or the trial conversion (once).
        case firstRenew = "first_renew"
        /// Auto-renew was turned off.
        case cancelled
        /// Auto-renew was turned back on.
        case resumed
        /// The plan ended and the user is no longer Premium.
        case expired
        /// Apple could not charge the renewal.
        case billFail = "bill_fail"
        /// A user whose plan expired bought again.
        case resubscribed
    }

    private struct State: Codable {
        var tag: String
        var entry: String?
        var lastPurchase: TimeInterval
        var cancelled = false
        var billFail = false
        var firstRenewLogged = false
    }

    private static let storageKey = "RenewalTracker.state"
    private static let expiredKey = "RenewalTracker.expired"

    /// Reads the Premium entitlement from `info`. `fromPurchase` is true only for the result of a purchase.
    @MainActor
    static func process(_ info: CustomerInfo, fromPurchase: Bool) {
        let entitlement = info.entitlements[SubscriptionProduct.entitlementID]
        let state = load()

        guard let entitlement, entitlement.isActive else {
            // The plan ended.
            if let state {
                log(.expired, state)
                UserDefaults.standard.set(true, forKey: expiredKey)
                save(nil)
            }
            return
        }
        // A free trial belongs to `TrialTracker`; the paid plan starts when it converts.
        guard entitlement.periodType != .trial else { return }

        let purchaseDate = entitlement.latestPurchaseDate?.timeIntervalSince1970 ?? 0
        let tag = Self.tag(for: entitlement.productIdentifier)
        let bought = fromPurchase || TrialTracker.purchaseInFlight

        guard var current = state else {
            let entry = bought ? IAPTracker.currentEntry : TrialTracker.takeConvertedEntry()
            let fresh = State(tag: tag, entry: entry, lastPurchase: purchaseDate)
            if UserDefaults.standard.bool(forKey: expiredKey) {
                UserDefaults.standard.set(false, forKey: expiredKey)
                log(.resubscribed, fresh)
            }
            save(fresh)
            return
        }

        if current.tag != tag {
            // Monthly <-> Yearly: a new period starts, so this is not a renewal.
            AnalyticsManager.shared.log(name("sub_to_\(tag == "y" ? "year" : "month")", entry: current.entry),
                                        marksPremium: false, clarity: true)
            current.tag = tag
            current.lastPurchase = purchaseDate
            current.firstRenewLogged = false
        } else if purchaseDate > current.lastPurchase + 1 {
            current.lastPurchase = purchaseDate
            log(.renewed, current)
            if !current.firstRenewLogged {
                current.firstRenewLogged = true
                log(.firstRenew, current)
            }
        }

        if !entitlement.willRenew, !current.cancelled {
            current.cancelled = true
            log(.cancelled, current)
        } else if entitlement.willRenew, current.cancelled {
            current.cancelled = false
            log(.resumed, current)
        }

        if entitlement.billingIssueDetectedAt != nil {
            if !current.billFail {
                current.billFail = true
                log(.billFail, current)
            }
        } else {
            current.billFail = false
        }
        save(current)
    }

    @MainActor
    private static func log(_ step: Step, _ state: State) {
        AnalyticsManager.shared.log(name("\(state.tag)sub_\(step.rawValue)", entry: state.entry), marksPremium: false, clarity: true)
    }

    private static func name(_ body: String, entry: String?) -> String {
        entry.map { "\($0)_\(body)" } ?? body
    }

    private static func tag(for productID: String) -> String {
        [.monthly, .monthlyTrial].contains(SubscriptionProduct(rawValue: productID)) ? "m" : "y"
    }

    private static func load() -> State? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    private static func save(_ state: State?) {
        let data = state.flatMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
