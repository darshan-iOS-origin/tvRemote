import Foundation
import RevenueCat

/// Analytics for the free trial, named with the entry point that opened the IAP screen and the plan:
/// `<entry>_<m|y>trial_<step>`, e.g. `setting_banner_mtrial_started`. `m` is a Monthly trial, `y` a Yearly one
/// (a full plan word would break the 35 character limit for long entries such as `history_locked_tv`).
/// Events carry no parameters.
///
/// The app only sees a trial change when it opens: RevenueCat's customer info is read in
/// `SubscriptionManager.apply`, which calls `process`. The entry point is saved at purchase time and reused
/// for the later events. A trial the app did not see being bought (another device, an older app version)
/// is logged without the entry: `mtrial_converted`. Each step is logged once per trial.
enum TrialTracker {

    enum Step: String {
        /// A purchase started the trial.
        case started
        /// The trial ended and the paid subscription began.
        case converted
        /// Auto-renew was turned off during the trial.
        case cancelled
        /// Auto-renew was turned back on during the trial.
        case resumed
        /// The trial ended and the user did not become a paid subscriber.
        case expired
        /// Apple could not charge when the trial ended.
        case billFail = "bill_fail"
    }

    private struct State: Codable {
        var tag: String
        var entry: String?
        var purchaseDate: TimeInterval
        var cancelled = false
        var resumed = false
        var billFail = false
    }

    private static let storageKey = "TrialTracker.state"
    private static let convertedEntryKey = "TrialTracker.convertedEntry"

    /// The entry point of the trial that just converted, handed over once to `RenewalTracker`.
    static func takeConvertedEntry() -> String? {
        let entry = UserDefaults.standard.string(forKey: convertedEntryKey)
        UserDefaults.standard.removeObject(forKey: convertedEntryKey)
        return entry
    }

    /// True while a purchase is running, so customer info that arrives from the stream just before the
    /// purchase call returns still counts as that purchase.
    static var purchaseInFlight = false

    /// Reads the Premium entitlement from `info`. `fromPurchase` is true only for the result of a purchase,
    /// so a restore or a launch never counts as a trial start.
    @MainActor
    static func process(_ info: CustomerInfo, fromPurchase: Bool) {
        let entitlement = info.entitlements[SubscriptionProduct.entitlementID]
        var state = load()

        if let entitlement, entitlement.isActive, entitlement.periodType == .trial {
            let date = entitlement.latestPurchaseDate?.timeIntervalSince1970 ?? 0
            if state == nil || state?.purchaseDate != date {
                state = State(tag: tag(for: entitlement.productIdentifier), entry: IAPTracker.currentEntry,
                              purchaseDate: date)
                if fromPurchase || purchaseInFlight {
                    log(.started, state!)
                } else {
                    // Not bought here: the entry is unknown.
                    state?.entry = nil
                }
            }
            guard var current = state else { return }
            if !entitlement.willRenew, !current.cancelled {
                current.cancelled = true
                log(.cancelled, current)
            } else if entitlement.willRenew, current.cancelled, !current.resumed {
                current.resumed = true
                log(.resumed, current)
            }
            if entitlement.billingIssueDetectedAt != nil, !current.billFail {
                current.billFail = true
                log(.billFail, current)
            }
            save(current)
        } else if let current = state {
            if let entitlement, entitlement.isActive {
                log(.converted, current)
                // The paid plan keeps the entry point (`RenewalTracker`).
                UserDefaults.standard.set(current.entry, forKey: convertedEntryKey)
            } else {
                log(.expired, current)
            }
            save(nil)
        }
    }

    @MainActor
    private static func log(_ step: Step, _ state: State) {
        let name = "\(state.tag)trial_\(step.rawValue)"
        AnalyticsManager.shared.log(state.entry.map { "\($0)_\(name)" } ?? name, marksPremium: false, clarity: true)
    }

    private static func tag(for productID: String) -> String {
        SubscriptionProduct(rawValue: productID) == .monthly ? "m" : "y"
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
