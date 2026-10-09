import UIKit
import RevenueCat

/// The one place that talks to RevenueCat. The rest of the app asks it three things: is the user Premium
/// (`isPremium`), what do the plans cost (`display(for:)`), and buy or restore (`purchase`, `restore`).
///
/// `isPremium` is the single flag every premium feature checks. It is true while the RevenueCat entitlement
/// `SubscriptionProduct.entitlementID` is active, and it is cached in `AppSettings.isPremium`, so the next
/// launch is right before the network has answered. Changes post `didChangeNotification`.
///
/// Set up in `AppDelegate`: `SubscriptionManager.shared.configure()`.
/// Docs: https://www.revenuecat.com/docs/getting-started/configuring-sdk and
/// https://www.revenuecat.com/docs/customers/customer-info
@MainActor
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    /// Posted on the main thread whenever `isPremium` changes.
    static let didChangeNotification = Notification.Name("SubscriptionManager.didChange")

    /// What a plan card shows. `trial` is nil when the plan has no free trial or the user already used it.
    struct PlanDisplay {
        var price: String
        var perDay: String
        var trial: String?
    }

    enum PurchaseOutcome {
        case purchased
        case cancelled
    }

    enum SubscriptionError: LocalizedError {
        case notConfigured
        case productUnavailable

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Purchases are not available right now. Please try again later."
            case .productUnavailable:
                return "This plan is not available right now. Please check your connection and try again."
            }
        }
    }

    /// True while the user has the Premium entitlement. Check this for every premium feature.
    private(set) var isPremium: Bool = AppSettings.isPremium

    private(set) var isConfigured = false

    private var products: [SubscriptionProduct: StoreProduct] = [:]
    private var trialEligibility: [SubscriptionProduct: Bool] = [:]
    private var updatesTask: Task<Void, Never>?
    private var isLoadingProducts = false

    private init() {}

    // MARK: - Setup

    /// Starts RevenueCat. Call once, early (`AppDelegate`). A missing API key is logged and purchases stay off;
    /// the app keeps working as a free app.
    func configure() {
        ThreadManager.once(token: "SubscriptionManager.configure") {
            guard let key = Self.apiKey else {
                SubscriptionLogger.missingAPIKey()
                return
            }
            #if DEBUG
            Purchases.logLevel = .debug
            let level = "debug"
            #else
            Purchases.logLevel = .warn
            let level = "warn"
            #endif
            Purchases.configure(withAPIKey: key)
            isConfigured = true
            SubscriptionLogger.configured(logLevel: level)
            observeCustomerInfo()
            Task { await refresh() }
        }
    }

    /// The public Apple SDK key from `Config/Secrets.xcconfig` (through Info.plist), or nil if it is missing.
    private static var apiKey: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // An unset xcconfig variable shows up as the literal "$(REVENUECAT_API_KEY)".
        guard !value.isEmpty, !value.hasPrefix("$("), !value.contains("PASTE") else { return nil }
        return value
    }

    /// Follows customer info for as long as the app runs, and checks again each time the app comes forward.
    private func observeCustomerInfo() {
        updatesTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: - Customer info

    /// Reads the customer info (RevenueCat serves it from its cache when it is fresh).
    func refresh() async {
        guard isConfigured else { return }
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            SubscriptionLogger.customerInfoFailed(error)
        }
    }

    private func apply(_ info: CustomerInfo) {
        SubscriptionLogger.customerInfo(info)
        let active = info.entitlements[SubscriptionProduct.entitlementID]?.isActive == true
        guard active != isPremium else { return }
        isPremium = active
        AppSettings.isPremium = active
        SubscriptionLogger.premiumChanged(active)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    // MARK: - Products

    /// Loads the three products from the store, retrying a couple of times on a bad connection. Safe to
    /// call again; it does nothing while a load is running.
    func loadProducts() async {
        guard isConfigured, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let ids = Array(SubscriptionProduct.allIDs)
            let found = try await ThreadManager.retry(maxAttempts: 3, delay: 1, useBackoff: true) {
                let list = await Purchases.shared.products(ids)
                if list.isEmpty { throw SubscriptionError.productUnavailable }
                return list
            }
            for product in found {
                if let plan = SubscriptionProduct(rawValue: product.productIdentifier) {
                    products[plan] = product
                }
            }
            SubscriptionLogger.fetchedProducts(found: found.map(\.productIdentifier), requested: SubscriptionProduct.allIDs)
            for (plan, product) in products {
                trialEligibility[plan] = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product) == .eligible
            }
            NotificationCenter.default.post(name: Self.productsDidLoadNotification, object: nil)
        } catch {
            SubscriptionLogger.fetchFailed(error)
        }
    }

    /// Posted on the main thread when the store prices have been loaded, so open screens can redraw.
    static let productsDidLoadNotification = Notification.Name("SubscriptionManager.productsDidLoad")

    var hasProducts: Bool {
        !products.isEmpty
    }

    /// Price, price per day and free-trial text for a plan, or nil until its product has loaded.
    func display(for plan: SubscriptionProduct) -> PlanDisplay? {
        guard let product = products[plan] else { return nil }
        let perDay = (product.price as NSDecimalNumber).doubleValue / Double(plan.daysPerPeriod)
        return PlanDisplay(
            price: product.localizedPriceString,
            perDay: "\(Self.format(perDay, like: product)) Per Day",
            trial: trialText(for: plan, product: product)
        )
    }

    /// The price times two as a string in the store's currency: the "regular price" next to a 50% offer.
    func doubledPriceString(for plan: SubscriptionProduct) -> String? {
        guard let product = products[plan] else { return nil }
        return Self.format((product.price as NSDecimalNumber).doubleValue * 2, like: product)
    }

    private func trialText(for plan: SubscriptionProduct, product: StoreProduct) -> String? {
        guard trialEligibility[plan] == true,
              let intro = product.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let count = intro.subscriptionPeriod.value
        let days: Int
        switch intro.subscriptionPeriod.unit {
        case .day: days = count
        case .week: days = count * 7
        case .month: return "\(count) Month Free Trial"
        case .year: return "\(count) Year Free Trial"
        @unknown default: return nil
        }
        return "\(days) Day Free Trial"
    }

    private static func format(_ amount: Double, like product: StoreProduct) -> String {
        if let formatter = product.priceFormatter, let text = formatter.string(from: NSNumber(value: amount)) {
            return text
        }
        return String(format: "%.2f", amount)
    }

    // MARK: - Buying

    /// Buys a plan. Returns `.cancelled` if the user backed out of the payment sheet; throws for a real
    /// failure. `isPremium` updates through the customer info that comes back.
    func purchase(_ plan: SubscriptionProduct) async throws -> PurchaseOutcome {
        guard isConfigured else { throw SubscriptionError.notConfigured }
        if products[plan] == nil { await loadProducts() }
        guard let product = products[plan] else { throw SubscriptionError.productUnavailable }

        SubscriptionLogger.purchaseStarted(plan.rawValue)
        do {
            let result = try await Purchases.shared.purchase(product: product)
            if result.userCancelled {
                SubscriptionLogger.purchaseCancelled(plan.rawValue)
                return .cancelled
            }
            apply(result.customerInfo)
            SubscriptionLogger.purchaseSucceeded(plan.rawValue)
            return .purchased
        } catch {
            SubscriptionLogger.purchaseFailed(plan.rawValue, error: error)
            throw error
        }
    }

    /// Restores earlier purchases (new phone, reinstall). Returns whether the user is Premium afterwards.
    @discardableResult
    func restore() async throws -> Bool {
        guard isConfigured else { throw SubscriptionError.notConfigured }
        SubscriptionLogger.restoreStarted()
        do {
            apply(try await Purchases.shared.restorePurchases())
            SubscriptionLogger.restoreSucceeded(isPremium: isPremium)
            return isPremium
        } catch {
            SubscriptionLogger.restoreFailed(error)
            throw error
        }
    }

    // MARK: - Messages

    /// A sentence for the user when a purchase or restore fails.
    func userMessage(for error: Error) -> String {
        if let known = error as? SubscriptionError {
            return known.errorDescription ?? known.localizedDescription
        }
        if let code = error as? ErrorCode {
            switch code {
            case .paymentPendingError:
                return "Your payment is pending approval. Premium will turn on once it is approved."
            case .networkError, .offlineConnectionError:
                return "Could not reach the App Store. Check your connection and try again."
            case .purchaseNotAllowedError:
                return "Purchases are not allowed on this device."
            case .productAlreadyPurchasedError:
                return "You already own this plan. Tap Restore Purchase to unlock it."
            default:
                break
            }
        }
        return "Something went wrong. Please try again."
    }

    // MARK: - Gating

    /// Runs `onGranted` for a Premium user; otherwise opens the Subscription screen over `presenter`.
    /// Every premium feature can start with this one call.
    func requirePremium(from presenter: UIViewController, onGranted: () -> Void) {
        if isPremium {
            onGranted()
        } else {
            NavigationManager.shared.showSubscription(from: presenter)
        }
    }
}
