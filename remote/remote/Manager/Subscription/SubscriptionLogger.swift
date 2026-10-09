import Foundation
import RevenueCat

/// Everything the subscription code writes to the log goes through here, so it all carries the same
/// category and the same rules: no receipts, tokens or user IDs, only what a developer needs to follow a
/// purchase. It writes through `LoggerManager`, so lines also reach the in-app log viewer.
enum SubscriptionLogger {

    private static let category = "Subscription"

    static func configured(logLevel: String) {
        LoggerManager.success("RevenueCat configured (log level \(logLevel))", category: category)
    }

    static func missingAPIKey() {
        LoggerManager.error(
            "RevenueCat API key is missing. Paste your public Apple SDK key into AppConfig.revenueCatAPIKey. Purchases are off until then.",
            category: category
        )
    }

    static func fetchedProducts(found: [String], requested: Set<String>) {
        let missing = requested.subtracting(found)
        if missing.isEmpty {
            LoggerManager.success("Loaded \(found.count) product(s)", category: category)
        } else {
            LoggerManager.warning(
                "Loaded \(found.count) of \(requested.count) product(s). Not found: \(missing.sorted().joined(separator: ", ")). Check App Store Connect and RevenueCat.",
                category: category
            )
        }
    }

    static func fetchFailed(_ error: Error, requested: Set<String>) {
        if let known = error as? SubscriptionManager.SubscriptionError, case .productUnavailable = known {
            LoggerManager.error(
                "The App Store returned no products for: \(requested.sorted().joined(separator: ", ")). Check that the subscriptions exist and are Ready to Submit in App Store Connect (price, localization, review screenshot), the Paid Apps agreement is active, the IDs match exactly, and you run with a Sandbox account or a StoreKit configuration file.",
                category: category
            )
        } else {
            LoggerManager.error("Could not load products: \(error.localizedDescription)", category: category)
        }
    }

    static func purchaseStarted(_ productID: String) {
        LoggerManager.info("Purchase started: \(productID)", category: category)
    }

    static func purchaseSucceeded(_ productID: String) {
        LoggerManager.success("Purchase finished: \(productID)", category: category)
    }

    static func purchaseCancelled(_ productID: String) {
        LoggerManager.info("Purchase cancelled by the user: \(productID)", category: category)
    }

    static func purchaseFailed(_ productID: String, error: Error) {
        LoggerManager.error("Purchase failed: \(productID): \(error.localizedDescription)", category: category)
    }

    static func restoreStarted() {
        LoggerManager.info("Restore started", category: category)
    }

    static func restoreSucceeded(isPremium: Bool) {
        LoggerManager.success("Restore finished (premium: \(isPremium))", category: category)
    }

    static func restoreFailed(_ error: Error) {
        LoggerManager.error("Restore failed: \(error.localizedDescription)", category: category)
    }

    static func customerInfoFailed(_ error: Error) {
        LoggerManager.warning("Could not read customer info: \(error.localizedDescription)", category: category)
    }

    static func premiumChanged(_ isPremium: Bool) {
        LoggerManager.info("Premium is now \(isPremium ? "ON" : "OFF")", category: category)
    }

    /// The state of the entitlement: active or not, and for an active one the period type (trial, intro,
    /// normal), the expiry and whether it renews.
    static func customerInfo(_ info: CustomerInfo) {
        guard let entitlement = info.entitlements[SubscriptionProduct.entitlementID], entitlement.isActive else {
            LoggerManager.info("Customer info: no active '\(SubscriptionProduct.entitlementID)' entitlement", category: category)
            return
        }
        let period: String
        switch entitlement.periodType {
        case .trial: period = "trial"
        case .intro: period = "intro"
        case .normal: period = "normal"
        @unknown default: period = "unknown"
        }
        let expires = entitlement.expirationDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "never"
        LoggerManager.info(
            "Customer info: '\(SubscriptionProduct.entitlementID)' active, product \(entitlement.productIdentifier), period \(period), expires \(expires), renews \(entitlement.willRenew)",
            category: category
        )
    }
}
