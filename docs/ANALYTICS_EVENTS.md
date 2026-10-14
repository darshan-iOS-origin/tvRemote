# Analytics Events — Integration Spec (iOS, UIKit, Swift)

A self-contained spec for adding event tracking to an iOS app. It holds everything needed: the SDKs,
the rules, the event naming scheme, and the full source of every class. Nothing here depends on another
repository. Read it top to bottom, then build it in the target app.

**For the AI implementing this:** create the files in §4 exactly as given (adjust only the lines marked
`// APP:`), then build the app's own event catalog (§5) by walking every screen, button, alert and feature
of the target app, following the rules in §2. Do not invent parameters; do not skip any screen or button.

---

## 1. SDKs

Add with Swift Package Manager:

| SDK | Package | Products | Purpose |
|---|---|---|---|
| Firebase | `https://github.com/firebase/firebase-ios-sdk` | FirebaseAnalytics, FirebaseCrashlytics, FirebaseRemoteConfig | All events, crashes, remote switches |
| Facebook | `https://github.com/facebook/facebook-ios-sdk` | FacebookCore | Screen events + IAP entry (ads attribution) |
| Microsoft Clarity | `https://github.com/microsoft/clarity-apps` | Clarity | Session recordings + screen and IAP events |
| RevenueCat | `https://github.com/RevenueCat/purchases-ios-spm` | RevenueCat | Subscriptions; source of trial/renewal events |
| OneSignal (optional) | `https://github.com/OneSignal/OneSignal-XCFramework` | OneSignalFramework | Push only, no events |

**Project setup:**
- `GoogleService-Info.plist` in the app target (Analytics enabled in it).
- Crashlytics: add the Run Script build phase `"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"`
  with dSYM input files, and set Debug Information Format = DWARF with dSYM.
- `Info.plist`: `SKAdNetworkItems` (the Google AdMob / Facebook SKAdNetwork ID list), and
  `NSUserTrackingUsageDescription` (or build setting `INFOPLIST_KEY_NSUserTrackingUsageDescription`).
- Scheme → Run → Arguments: `-FIRDebugEnabled` to see events in Firebase DebugView.
- `Secrets.swift` — **git-ignored**, never committed:

```swift
enum Secrets {
    static let revenueCatAPIKey = ""     // APP: RevenueCat public Apple SDK key
    static let oneSignalAppID = ""       // APP: optional
    static let facebookAppID = ""        // APP
    static let facebookClientToken = ""  // APP
    static let clarityProjectID = ""     // APP
}
```

**Launch order** in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`:

```swift
FirebaseManager.configure()                       // 1. always first
CrashlyticsManager.shared.configure()             // 2. needs Firebase
AnalyticsManager.shared.logAppColdStart()         // 3. app_cold_start
RemoteConfigManager.shared.setUp()                // 4.
Task { await RemoteConfigManager.shared.fetchAndActivate() }
SubscriptionManager.shared.configure()            // 5. RevenueCat (your own class, see §4.12)
OneSignalManager.shared.configure(launchOptions: launchOptions) // optional
FacebookManager.shared.configure(application: application, launchOptions: launchOptions)
ClarityManager.shared.configure()                 // main thread
```

Forward URL callbacks to Facebook from `SceneDelegate` (`scene(_:openURLContexts:)`, `scene(_:continue:)`).

---

## 2. Rules every event follows

1. **Name format:** 1–**35** characters, only `a-z A-Z 0-9 _`, starts with a letter, never starts with
   `firebase_`, `google_` or `ga_`. (Firebase allows 40; 35 leaves room for the `pro_` prefix.) A name that
   breaks this is **dropped** and logged — it is never truncated. The limit applies **after** `pro_` is added,
   so taps and feature results must be ≤ 31 characters without the prefix.
2. **No parameters.** Everything (screen, entry point, plan, reason) is encoded in the name.
3. **One constants enum** (`AppEvents`, §5) holds every name. Call sites never build strings, except the
   builders in this spec (IAP, trial, renewal trackers, and `func` helpers like `appTap(id)`).
4. **`pro_` prefix:** taps and feature success/fail events are sent as `pro_<name>` when the user is Premium.
   Screens, permissions, IAP, trial and renewal events never get the prefix.
5. **Once per install:** permission events use `logOnce` (a `UserDefaults` flag `analytics.once.<name>`).
6. **Console:** every send prints `📊 EVENT_TRACK | 🔥 Firebase | <name>` (📘 Facebook, 🔭 Clarity);
   drops print `DROPPED <name>: <reason>`. Filter the Xcode console with `EVENT_TRACK`.
7. **Every screen** (including custom dialogs and IAP screens) logs its screen event in `viewDidAppear`.
8. **Every button / tappable view** logs one tap event. **Every plain alert's OK** has its own event.
9. **Every feature** logs one `_ok` event and one `_fail_<reason>` event per distinct error.

### Routing

| Event group | Firebase | Facebook | Clarity | `pro_` |
|---|---|---|---|---|
| `app_cold_start` | ✅ | — | — | no |
| Screens `screen_*` | ✅ | ✅ same name | ✅ same name + screen name | no |
| Permissions | ✅ once/install | — | — | no |
| IAP open `iap_open_<entry>` | ✅ | — | ✅ | no |
| IAP open per screen `iap_open_<entry>_<main\|offer\|trial>` | — | ✅ only | — | no |
| IAP flow / purchase / restore | ✅ | — | ✅ | no |
| Trial / renewal | ✅ | — | ✅ | no |
| Taps `*_tap` | ✅ | — | only IAP-related taps | yes |
| Feature results `*_ok`, `*_fail_*` | ✅ | — | — | yes |

---

## 3. Event naming scheme

| Group | Pattern | Example |
|---|---|---|
| Lifecycle | `app_cold_start` | `app_cold_start` |
| Screen | `screen_<screen>` | `screen_settings`, `screen_onboarding_2` |
| Tap | `<screen>_<element>_tap` | `settings_share_tap`, `home_add_tap` |
| Alert OK | `<screen>_<alert>_alert_ok_tap` | `voice_error_alert_ok_tap` |
| Sheet closed | `<screen>_<sheet>_cancel_tap` | `settings_share_cancel_tap` |
| Feature ok | `<feature>_ok` | `connect_ok`, `export_ok` |
| Feature fail | `<feature>_fail_<reason>` | `connect_fail_timeout` |
| Permission | `<perm>_permission_trigger\|allowed\|deny` | `att_permission_allowed` |
| Settings-redirect alert | `<perm>_settings_alert\|open\|cancel` | `mic_settings_open` |
| IAP open | `iap_open_<entry>` | `iap_open_settings_banner` |
| IAP step | `<entry>_<step>` | `settings_banner_year_plan_change` |
| IAP purchase | `<entry>_<screen>_buy_start\|ok\|cancel\|fail` | `splash_offer_buy_ok` |
| IAP restore | `<entry>_<screen>_restore\|restored\|restore_no` | `splash_main_restored` |
| Trial | `<entry>_<m\|y>trial_<step>` | `settings_banner_ytrial_converted` |
| Renewal | `<entry>_<m\|y>sub_<step>` | `splash_msub_renewed` |
| Plan switch | `<entry>_sub_to_year\|month` | `splash_sub_to_year` |

Keep `<entry>` short (≤ 15 chars) so trial/renewal names stay ≤ 35.

### Fixed event sets (use as-is in every app)

**Permissions** (`logOnce`, only when the system alert really appeared; `restricted` counts as deny):
`att_permission_*`, `notification_permission_*`, `mic_permission_*`, `speech_permission_*`,
`local_network_permission_*`, `camera_permission_*`, `photos_permission_*`, `location_permission_*` — each with
`_trigger`, `_allowed`, `_deny`. Add only the ones the app asks for.

**IAP steps:** `year_plan_default`, `month_plan_change`, `week_plan_change`, `year_plan_change`, `main_close`, `offer_close`,
`trial_close`, `privacy_tap`, `terms_tap`.
**Purchase:** `buy_start`, `buy_ok`, `buy_cancel`, `buy_fail`. **Restore:** `restore`, `restored`, `restore_no`.
**IAP screens:** `main` (main paywall), `offer` (discount paywall), `trial` (free-trial paywall).

**Trial steps** (each once per trial): `started`, `converted`, `cancelled`, `resumed`, `expired`, `bill_fail`.
**Renewal steps:** `renewed`, `first_renew` (once), `cancelled`, `resumed`, `expired`, `bill_fail`, `resubscribed`.
Without a known entry (bought on another device or older version) the entry part is omitted: `mtrial_converted`.

**IAP alert taps** (also sent to Clarity): `premium_start_tap` (Premium Activated → Start),
`iap_buy_fail_alert_ok_tap`, `iap_restore_none_ok_tap`, `iap_restore_fail_ok_tap`.

**Shared dialogs:** `screen_no_internet_alert`, `no_internet_retry_tap`, `no_internet_close_tap`.
The system rate prompt has no event (iOS gives no callback).

**Remote Config:** `rc_fetch_ok`, `rc_fetch_fail`.

---

## 4. Source code

Put these under `Manager/Analytics/` (or the app's equivalent). They compile as given once the SDKs are added.

### 4.1 AppLog — tiny console logger (replace with the app's logger if it has one)

```swift
import os

enum AppLog {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "app")
    static func info(_ m: String, category: String = "App")    { logger.info("ℹ️ [\(category)] \(m)") }
    static func success(_ m: String, category: String = "App") { logger.info("✅ [\(category)] \(m)") }
    static func warning(_ m: String, category: String = "App") { logger.warning("⚠️ [\(category)] \(m)") }
    static func error(_ m: String, category: String = "App")   { logger.error("❌ [\(category)] \(m)") }
}
```

### 4.2 EventLog

```swift
import Foundation

/// One console format for every analytics event. Filter the Xcode console with `EVENT_TRACK`.
enum EventLog {
    enum Sink {
        case firebase, facebook, clarity
        var emoji: String { switch self { case .firebase: "🔥"; case .facebook: "📘"; case .clarity: "🔭" } }
        var name: String { switch self { case .firebase: "Firebase"; case .facebook: "Facebook"; case .clarity: "Clarity" } }
    }

    static let tag = "📊 EVENT_TRACK"

    static func sent(_ sink: Sink, _ name: String, details: String = "") {
        AppLog.success("\(tag) | \(sink.emoji) \(sink.name) | \(name)\(details)", category: sink.name)
    }

    static func dropped(_ sink: Sink, _ name: String, reason: String) {
        AppLog.error("\(tag) | \(sink.emoji) \(sink.name) | DROPPED \(name): \(reason)", category: sink.name)
    }
}
```

### 4.3 FirebaseManager + CrashlyticsManager

```swift
import FirebaseCore
import FirebaseCrashlytics

enum FirebaseManager {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        guard let options = FirebaseOptions.defaultOptions() else {
            AppLog.error("GoogleService-Info.plist not found", category: "Firebase"); return
        }
        #if DEBUG
        FirebaseConfiguration.shared.setLoggerLevel(.debug)   // SDK prints "Logging event: ..."
        #endif
        FirebaseApp.configure(options: options)
        AppLog.success("Firebase configured", category: "Firebase")
    }
}

final class CrashlyticsManager {
    static let shared = CrashlyticsManager()
    private(set) var isConfigured = false
    private init() {}

    func configure() {
        guard !isConfigured, FirebaseApp.app() != nil else { return }
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        isConfigured = true
    }
    func log(_ message: String) { if isConfigured { Crashlytics.crashlytics().log(message) } }
    func record(error: Error) { if isConfigured { Crashlytics.crashlytics().record(error: error) } }
    func setCustomValue(_ value: Any, forKey key: String) {
        if isConfigured { Crashlytics.crashlytics().setCustomValue(value, forKey: key) }
    }
}
```

### 4.4 AnalyticsManager — the only entry point for events

```swift
import FirebaseAnalytics
import FirebaseCore

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    private init() {}

    static let maxNameLength = 35
    static let premiumPrefix = "pro_"

    /// APP: return the app's current Premium state (e.g. from SubscriptionManager / RevenueCat).
    static var isPremium: () -> Bool = { false }

    /// Taps that belong to the IAP flow but go through shared code; also sent to Clarity.
    static let clarityTaps: Set<String> = [
        AppEvents.Tap.premiumStart, AppEvents.Tap.purchaseFailedAlertOK,
        AppEvents.Tap.restoreNoneAlertOK, AppEvents.Tap.restoreFailedAlertOK
    ]

    /// `marksPremium`: true for taps and feature results (default) → `pro_` for Premium users.
    /// `clarity`: true for IAP-related events → also sent to Clarity under the same name.
    @discardableResult
    func log(_ rawName: String, parameters: [String: Any]? = nil, marksPremium: Bool = true, clarity: Bool = false) -> Bool {
        let name = marksPremium && Self.isPremium() ? Self.premiumPrefix + rawName : rawName
        guard Self.isValid(name) else {
            EventLog.dropped(.firebase, name, reason: "must be 1-\(Self.maxNameLength) letters, digits or _ and start with a letter")
            return false
        }
        if clarity || Self.clarityTaps.contains(rawName) { ClarityEvents.shared.log(name) }
        guard FirebaseApp.app() != nil else {
            EventLog.dropped(.firebase, name, reason: "Firebase is not configured"); return false
        }
        Analytics.logEvent(name, parameters: parameters)
        EventLog.sent(.firebase, name, details: parameters.map { " \($0)" } ?? "")
        return true
    }

    /// Only the first time ever on this install.
    func logOnce(_ name: String) {
        let key = "analytics.once.\(name)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        if log(name, marksPremium: false) { UserDefaults.standard.set(true, forKey: key) }
    }

    func logAppColdStart() { log(AppEvents.appColdStart, marksPremium: false) }

    /// Screen event → Firebase, Facebook and Clarity, same name. Call in `viewDidAppear`.
    func logScreen(_ name: String) {
        log(name, marksPremium: false)
        FacebookEvents.shared.logScreen(name)
        ClarityEvents.shared.logScreen(name)
    }

    private static func isValid(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first, name.count <= maxNameLength,
              !name.hasPrefix("firebase_"), !name.hasPrefix("google_"), !name.hasPrefix("ga_") else { return false }
        let letters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let allowed = letters.union(CharacterSet(charactersIn: "0123456789_"))
        return letters.contains(first) && name.unicodeScalars.allSatisfy(allowed.contains)
    }
}
```

### 4.5 FacebookManager + FacebookEvents

```swift
import AppTrackingTransparency
import FacebookCore
import UIKit

final class FacebookManager {
    static let shared = FacebookManager()
    private(set) var isConfigured = false
    private init() {}

    func configure(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !isConfigured else { return }
        Settings.shared.appID = Secrets.facebookAppID
        Settings.shared.clientToken = Secrets.facebookClientToken
        Settings.shared.displayName = "APP NAME"            // APP
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true
        #if DEBUG
        Settings.shared.enableLoggingBehavior(.appEvents)
        Settings.shared.enableLoggingBehavior(.networkRequests)
        Settings.shared.enableLoggingBehavior(.informational)
        #endif
        syncTrackingPermission()
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.syncTrackingPermission() }
        }
        _ = ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        isConfigured = true
    }

    /// Only an ATT `.authorized` answer turns advertiser tracking on. Call again right after the ATT prompt.
    @MainActor
    func syncTrackingPermission() {
        let allowed = ATTrackingManager.trackingAuthorizationStatus == .authorized
        guard Settings.shared.isAdvertiserTrackingEnabled != allowed else { return }
        Settings.shared.isAdvertiserTrackingEnabled = allowed
    }

    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        for c in contexts {
            ApplicationDelegate.shared.application(UIApplication.shared, open: c.url,
                                                   sourceApplication: c.options.sourceApplication,
                                                   annotation: c.options.annotation)
        }
    }

    @discardableResult
    func application(_ application: UIApplication, continue userActivity: NSUserActivity) -> Bool {
        ApplicationDelegate.shared.application(application, continue: userActivity)
    }
}

/// Only screen events and the per-screen IAP entry go to Facebook. No parameters.
final class FacebookEvents {
    static let shared = FacebookEvents()
    private init() {}

    @discardableResult func logScreen(_ name: String) -> Bool { send(name) }
    /// `iap_open_<entry>_<main|offer|trial>`, sent when an IAP screen appears. Firebase never gets it.
    @discardableResult func logIAPEntry(_ name: String) -> Bool { send(name) }

    private func send(_ name: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- ")
        guard !name.isEmpty, name.count <= 40, name.unicodeScalars.allSatisfy(allowed.contains) else {
            EventLog.dropped(.facebook, name, reason: "invalid name"); return false
        }
        guard FacebookManager.shared.isConfigured else {
            EventLog.dropped(.facebook, name, reason: "Facebook SDK is not configured"); return false
        }
        AppEvents.shared.logEvent(AppEvents.Name(name))
        #if DEBUG
        AppEvents.shared.flush()   // send now so the SDK log shows the request
        #endif
        EventLog.sent(.facebook, name)
        return true
    }
}
```

### 4.6 ClarityManager + ClarityEvents

```swift
import Clarity
import UIKit

final class ClarityManager {
    static let shared = ClarityManager()
    private(set) var isStarted = false
    private var isConfigured = false
    private init() {}

    func configure() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.configure() }; return }
        guard !isConfigured else { return }
        #if DEBUG
        let level = ClarityLogLevel.verbose
        #else
        let level = ClarityLogLevel.none
        #endif
        isStarted = ClaritySDK.initialize(config: ClarityConfig(projectId: Secrets.clarityProjectID, logLevel: level))
        isConfigured = true
        if isStarted {
            ClaritySDK.setOnSessionStartedCallback { _ in
                AppLog.info("Clarity session: \(ClaritySDK.getCurrentSessionUrl() ?? "no url")", category: "Clarity")
            }
        }
    }
}

/// Only screen events and IAP-related events go to Clarity, same names as Firebase. No parameters.
final class ClarityEvents {
    static let shared = ClarityEvents()
    private init() {}

    @discardableResult
    func log(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 254 else { EventLog.dropped(.clarity, name, reason: "invalid name"); return false }
        guard ClarityManager.shared.isStarted else { EventLog.dropped(.clarity, name, reason: "Clarity is not started"); return false }
        ClaritySDK.sendCustomEvent(value: name)
        EventLog.sent(.clarity, name)
        return true
    }

    func logScreen(_ name: String) {
        guard ClarityManager.shared.isStarted else { EventLog.dropped(.clarity, name, reason: "Clarity is not started"); return }
        ClaritySDK.setCurrentScreenName(name)
        log(name)
    }
}
```

### 4.7 PermissionLogger + launch permission prompts

```swift
import AppTrackingTransparency
import AVFoundation
import UIKit
import UserNotifications

/// Call `triggered` right before showing a system prompt, `finished` with the answer.
/// Events are logged once per install and only when the alert was really shown.
enum PermissionLogger {
    enum Permission: String {
        case att, notification, mic, speech, local_network, camera, photos, location
        var trigger: String { "\(rawValue)_permission_trigger" }
        var allowed: String { "\(rawValue)_permission_allowed" }
        var deny: String { "\(rawValue)_permission_deny" }
    }

    static func triggered(_ p: Permission) { AnalyticsManager.shared.logOnce(p.trigger) }

    static func finished(_ p: Permission, granted: Bool, prompted: Bool) {
        guard prompted else { return }      // silent status checks log nothing
        AnalyticsManager.shared.logOnce(granted ? p.allowed : p.deny)
    }
}

/// First launch: ATT only. Notifications are asked in RemoteVC on the 2nd launch; if denied, an Open Settings alert
/// (`notification_settings_alert|open|cancel`) shows once per launch.
enum LaunchPermissionManager {
    static func requestAll() async {
        await requestTracking()
    }

    @MainActor
    static func requestTracking() async {
        if UIApplication.shared.applicationState != .active {   // iOS ignores ATT unless active
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) { break }
        }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            FacebookManager.shared.syncTrackingPermission(); return
        }
        PermissionLogger.triggered(.att)
        let status = await ATTrackingManager.requestTrackingAuthorization()
        PermissionLogger.finished(.att, granted: status == .authorized, prompted: true)
        FacebookManager.shared.syncTrackingPermission()   // before any screen event goes out
    }

    static func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        PermissionLogger.triggered(.notification)
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        PermissionLogger.finished(.notification, granted: granted, prompted: true)
    }
}
```

For mic/speech/camera/photos/location/local network: wrap each system request the same way
(`triggered` → request → `finished(prompted: true)`). After a denial, if the app shows its own "Open Settings"
alert, log `<perm>_settings_alert` when shown, `<perm>_settings_open` / `<perm>_settings_cancel` on the buttons.

### 4.8 IAPTracker — IAP session events

```swift
import UIKit

/// Paywall screens adopt this so events can name the screen: `main`, `offer` or `trial`.
protocol IAPScreen: UIViewController { var iapScreenTag: String { get } }

enum IAPTracker {
    enum Step: String {
        case yearPlanDefault = "year_plan_default", monthPlanChange = "month_plan_change", yearPlanChange = "year_plan_change"
        case closeMain = "main_close", closeOffer = "offer_close", closeTrial = "trial_close"
        case privacyTap = "privacy_tap", termsTap = "terms_tap"
    }
    enum PurchaseStep: String { case start = "buy_start", success = "buy_ok", cancel = "buy_cancel", fail = "buy_fail" }
    enum RestoreStep: String { case tap = "restore", success = "restored", fail = "restore_no" }

    private static let openPrefix = "iap_open_"
    private(set) static var currentEntry: String?

    /// `event` is the `iap_open_<entry>` name the paywall was opened with.
    static func begin(event: String) {
        currentEntry = event.hasPrefix(openPrefix) ? String(event.dropFirst(openPrefix.count)) : event
    }
    static func end() { currentEntry = nil }

    @MainActor static func log(_ step: Step) {
        guard let e = currentEntry else { return }
        AnalyticsManager.shared.log("\(e)_\(step.rawValue)", marksPremium: false, clarity: true)
    }
    @MainActor static func log(_ step: PurchaseStep, from screen: IAPScreen) {
        guard let e = currentEntry else { return }
        AnalyticsManager.shared.log("\(e)_\(screen.iapScreenTag)_\(step.rawValue)", marksPremium: false, clarity: true)
    }
    @MainActor static func log(_ step: RestoreStep, from screen: IAPScreen) {
        guard let e = currentEntry else { return }
        AnalyticsManager.shared.log("\(e)_\(screen.iapScreenTag)_\(step.rawValue)", marksPremium: false, clarity: true)
    }
    /// Call in each paywall's `viewDidAppear` (after `logScreen`). Facebook only.
    @MainActor static func screenAppeared(_ screen: IAPScreen) {
        guard let e = currentEntry else { return }
        FacebookEvents.shared.logIAPEntry("\(openPrefix)\(e)_\(screen.iapScreenTag)")
    }
}
```

**Where to call:**
- Opening a paywall: `AnalyticsManager.shared.log(AppEvents.IAPEntry.x, marksPremium: false, clarity: true)`
  then `IAPTracker.begin(event: AppEvents.IAPEntry.x)`. Only when it really opens (Premium users skip it).
- Paywall appears with Yearly preselected: `IAPTracker.log(.yearPlanDefault)`.
- Plan card tap: `.monthPlanChange` / `.weekPlanChange` / `.yearPlanChange`. X button: `.closeMain/.closeOffer/.closeTrial`.
- Privacy/Terms links: `.privacyTap` / `.termsTap`.
- Buy: `.start` before, then `.success` / `.cancel` (user backed out) / `.fail`.
- Restore: `.tap`, then `.success` if it unlocked Premium, else `.fail`.
- Last paywall closed or Premium reached: `IAPTracker.end()`.

### 4.9 TrialTracker

```swift
import Foundation
import RevenueCat

/// `<entry>_<m|y>trial_<step>`. Seen only when customer info arrives (app open), not in real time.
enum TrialTracker {
    enum Step: String { case started, converted, cancelled, resumed, expired, billFail = "bill_fail" }

    private struct State: Codable {
        var tag: String; var entry: String?; var purchaseDate: TimeInterval
        var cancelled = false, resumed = false, billFail = false
    }
    private static let storageKey = "TrialTracker.state"
    private static let convertedEntryKey = "TrialTracker.convertedEntry"

    /// Set true around `Purchases.shared.purchase(...)`.
    static var purchaseInFlight = false

    static func takeConvertedEntry() -> String? {
        let e = UserDefaults.standard.string(forKey: convertedEntryKey)
        UserDefaults.standard.removeObject(forKey: convertedEntryKey)
        return e
    }

    @MainActor
    static func process(_ info: CustomerInfo, fromPurchase: Bool) {
        let ent = info.entitlements[SubscriptionConfig.entitlementID]
        var state = load()
        if let ent, ent.isActive, ent.periodType == .trial {
            let date = ent.latestPurchaseDate?.timeIntervalSince1970 ?? 0
            if state == nil || state?.purchaseDate != date {
                state = State(tag: SubscriptionConfig.planTag(ent.productIdentifier), entry: IAPTracker.currentEntry, purchaseDate: date)
                if fromPurchase || purchaseInFlight { log(.started, state!) } else { state?.entry = nil }
            }
            guard var cur = state else { return }
            if !ent.willRenew, !cur.cancelled { cur.cancelled = true; log(.cancelled, cur) }
            else if ent.willRenew, cur.cancelled, !cur.resumed { cur.resumed = true; log(.resumed, cur) }
            if ent.billingIssueDetectedAt != nil, !cur.billFail { cur.billFail = true; log(.billFail, cur) }
            save(cur)
        } else if let cur = state {
            if let ent, ent.isActive {
                log(.converted, cur)
                UserDefaults.standard.set(cur.entry, forKey: convertedEntryKey)  // handed to RenewalTracker
            } else {
                log(.expired, cur)
            }
            save(nil)
        }
    }

    @MainActor private static func log(_ step: Step, _ s: State) {
        let body = "\(s.tag)trial_\(step.rawValue)"
        AnalyticsManager.shared.log(s.entry.map { "\($0)_\(body)" } ?? body, marksPremium: false, clarity: true)
    }
    private static func load() -> State? {
        UserDefaults.standard.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(State.self, from: $0) }
    }
    private static func save(_ s: State?) {
        UserDefaults.standard.set(s.flatMap { try? JSONEncoder().encode($0) }, forKey: storageKey)
    }
}
```

### 4.10 RenewalTracker

```swift
import Foundation
import RevenueCat

/// `<entry>_<m|y>sub_<step>`; plan switch `<entry>_sub_to_year|month`. Trials belong to TrialTracker.
enum RenewalTracker {
    enum Step: String {
        case renewed, firstRenew = "first_renew", cancelled, resumed, expired, billFail = "bill_fail", resubscribed
    }
    private struct State: Codable {
        var tag: String; var entry: String?; var lastPurchase: TimeInterval
        var cancelled = false, billFail = false, firstRenewLogged = false
    }
    private static let storageKey = "RenewalTracker.state"
    private static let expiredKey = "RenewalTracker.expired"

    @MainActor
    static func process(_ info: CustomerInfo, fromPurchase: Bool) {
        let state = load()
        guard let ent = info.entitlements[SubscriptionConfig.entitlementID], ent.isActive else {
            if let state { log(.expired, state); UserDefaults.standard.set(true, forKey: expiredKey); save(nil) }
            return
        }
        guard ent.periodType != .trial else { return }
        let date = ent.latestPurchaseDate?.timeIntervalSince1970 ?? 0
        let tag = SubscriptionConfig.planTag(ent.productIdentifier)

        guard var cur = state else {
            let bought = fromPurchase || TrialTracker.purchaseInFlight
            let fresh = State(tag: tag, entry: bought ? IAPTracker.currentEntry : TrialTracker.takeConvertedEntry(), lastPurchase: date)
            if UserDefaults.standard.bool(forKey: expiredKey) {
                UserDefaults.standard.set(false, forKey: expiredKey); log(.resubscribed, fresh)
            }
            save(fresh); return
        }
        if cur.tag != tag {
            AnalyticsManager.shared.log(name("sub_to_\(tag == "y" ? "year" : "month")", cur.entry), marksPremium: false, clarity: true)
            cur.tag = tag; cur.lastPurchase = date; cur.firstRenewLogged = false
        } else if date > cur.lastPurchase + 1 {
            cur.lastPurchase = date
            log(.renewed, cur)
            if !cur.firstRenewLogged { cur.firstRenewLogged = true; log(.firstRenew, cur) }
        }
        if !ent.willRenew, !cur.cancelled { cur.cancelled = true; log(.cancelled, cur) }
        else if ent.willRenew, cur.cancelled { cur.cancelled = false; log(.resumed, cur) }
        if ent.billingIssueDetectedAt != nil { if !cur.billFail { cur.billFail = true; log(.billFail, cur) } }
        else { cur.billFail = false }
        save(cur)
    }

    @MainActor private static func log(_ step: Step, _ s: State) {
        AnalyticsManager.shared.log(name("\(s.tag)sub_\(step.rawValue)", s.entry), marksPremium: false, clarity: true)
    }
    private static func name(_ body: String, _ entry: String?) -> String { entry.map { "\($0)_\(body)" } ?? body }
    private static func load() -> State? {
        UserDefaults.standard.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(State.self, from: $0) }
    }
    private static func save(_ s: State?) {
        UserDefaults.standard.set(s.flatMap { try? JSONEncoder().encode($0) }, forKey: storageKey)
    }
}

/// APP: the RevenueCat entitlement and how to tell a monthly product from a yearly one.
enum SubscriptionConfig {
    static let entitlementID = "Pro Access"                       // APP
    static func planTag(_ productID: String) -> String {
        productID.lowercased().contains("month") ? "m" : "y"      // APP: adjust to the product IDs
    }
}
```

### 4.11 RemoteConfigManager

```swift
import FirebaseCore
import FirebaseRemoteConfig

final class RemoteConfigManager {
    static let shared = RemoteConfigManager()
    private init() {}

    /// APP: the keys exactly as in the Firebase console, each with a default.
    enum Key: String, CaseIterable {
        case iapMainScreen = "iap_main_screen"
        case iapYearOfferScreen = "iap_year_offer_screen"
        case iapFreeTrialScreen = "iap_free_trial_screen"
        var defaultValue: NSObject { NSNumber(value: true) }
    }

    private var rc: RemoteConfig?

    func setUp() {
        guard rc == nil, FirebaseApp.app() != nil else { return }
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        config.configSettings = settings
        config.setDefaults(Dictionary(uniqueKeysWithValues: Key.allCases.map { ($0.rawValue, $0.defaultValue) }))
        rc = config
    }

    func bool(_ key: Key) -> Bool { rc?.configValue(forKey: key.rawValue).boolValue ?? true }
    func int(_ key: Key) -> Int { max(0, rc?.configValue(forKey: key.rawValue).numberValue.intValue ?? 0) }

    /// Never waits longer than `timeout`; logs rc_fetch_ok / rc_fetch_fail.
    @discardableResult
    func fetchAndActivate(timeout: TimeInterval = 3) async -> Bool {
        setUp()
        guard let rc else { return false }
        return await withCheckedContinuation { cont in
            let lock = NSLock(); var done = false
            func finish(_ v: Bool) { lock.lock(); defer { lock.unlock() }; guard !done else { return }; done = true; cont.resume(returning: v) }
            rc.fetchAndActivate { status, error in
                let ok = error == nil && status != .error
                DispatchQueue.main.async { AnalyticsManager.shared.log(ok ? AppEvents.Outcome.remoteConfigOK : AppEvents.Outcome.remoteConfigFail) }
                finish(ok)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }
}
```

### 4.12 RevenueCat hook-up (inside the app's SubscriptionManager)

```swift
Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)
Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()   // Apple Search Ads

// Every CustomerInfo that arrives (stream, refresh on didBecomeActive, purchase, restore):
func apply(_ info: CustomerInfo, fromPurchase: Bool = false) {
    TrialTracker.process(info, fromPurchase: fromPurchase)
    RenewalTracker.process(info, fromPurchase: fromPurchase)
    isPremium = info.entitlements[SubscriptionConfig.entitlementID]?.isActive == true
}

// Purchase:
TrialTracker.purchaseInFlight = true
defer { TrialTracker.purchaseInFlight = false }
let result = try await Purchases.shared.purchase(product: product)
if !result.userCancelled { apply(result.customerInfo, fromPurchase: true) }
```

And set `AnalyticsManager.isPremium = { SubscriptionManager.shared.isPremium }` at launch.

### 4.13 IAP chain (optional, Remote Config driven)

Paywalls show in the fixed order **Main → Offer → Free Trial**, each enabled by its Remote Config bool
(`iap_main_screen`, `iap_year_offer_screen`, `iap_free_trial_screen`). Free Trial is the fallback when both
others are off. The switches have two sets: the plain keys for the first launch after a fresh install and
`iap_main_screen_second_time`, `iap_year_offer_screen_second_time`, `iap_free_trial_screen_second_time` for every launch
after that (`AppSettings.launchCount`). The X on each opens the next one on top; the last X dismisses the whole stack. A purchase or
restore that makes the user Premium ends the chain. `IAPTracker.begin` once at the start, `end` when it's over.

### 4.14 Rate prompt (optional)

Show `SKStoreReviewController` / `AppStore.requestReview` **at most once per install**, ~1.5 s after a
feature succeeded, never while `IAPTracker.currentEntry != nil`, only when the app is active. No analytics event.

---

## 5. The app's event catalog — `AppEvents`

Build this for the target app by listing **every** screen, button, alert and feature. Template:

```swift
enum AppEvents {
    static let appColdStart = "app_cold_start"

    /// One per view controller / custom dialog / paywall. Logged in viewDidAppear.
    enum Screen {
        static let splash = "screen_splash"
        static let onboardingPages = ["screen_onboarding_1", "screen_onboarding_2", "screen_onboarding_3"]
        static let home = "screen_home"
        static let settings = "screen_settings"
        static let subscription = "screen_subscription"
        static let offerSubscription = "screen_offer_subscription"
        static let freeTrial = "screen_free_trial"
        static let premiumActivated = "screen_premium_activated"
        static let noInternetAlert = "screen_no_internet_alert"
        // APP: one per screen
    }

    /// What opened the paywall. Keep the part after iap_open_ ≤ 15 chars.
    enum IAPEntry {
        static let splash = "iap_open_splash"
        static let settingsBanner = "iap_open_setting_banner"
        // APP: one per paywall entry point: "<feature>_limit", "<feature>_locked", ...
    }

    /// `<screen>_<element>_tap`. Arrays/dictionaries/functions for repeated elements.
    enum Tap {
        static let onboardingContinue = ["onboarding_1_continue_tap", "onboarding_2_continue_tap", "onboarding_3_continue_tap"]
        static let tabBar = ["tab_home_tap", "tab_settings_tap"]               // APP: in tab order
        static let settingShare = "setting_share_tap"
        static let settingRate = "setting_rate_tap"
        static let settingFeedback = "setting_feedback_tap"
        static let settingPrivacy = "setting_privacy_tap"
        static func appIcon(_ id: Int) -> String { "appicon_\(id)_tap" }

        static let noInternetRetry = "no_internet_retry_tap"
        static let noInternetClose = "no_internet_close_tap"
        static let premiumStart = "premium_start_tap"

        // OK of each plain alert — the alert helper should REQUIRE an okEvent argument
        static let purchaseFailedAlertOK = "iap_buy_fail_alert_ok_tap"
        static let restoreNoneAlertOK = "iap_restore_none_ok_tap"
        static let restoreFailedAlertOK = "iap_restore_fail_ok_tap"

        // System sheets closed without finishing
        static let settingShareCancel = "setting_share_cancel_tap"
        // APP: every button in every screen
    }

    /// Feature results. Map errors → names in functions so call sites never build names.
    enum Outcome {
        static let remoteConfigOK = "rc_fetch_ok"
        static let remoteConfigFail = "rc_fetch_fail"
        // APP example:
        // static let exportOK = "export_ok"
        // static func exportFail(for error: Error) -> String {
        //     switch error as? ExportError {
        //     case .noSpace?: return "export_fail_nospace"
        //     case .timedOut?: return "export_fail_timeout"
        //     default: return "export_fail_other"
        //     }
        // }
    }
}
```

**Alert helper that forces an OK event:**

```swift
extension UIViewController {
    func showSimpleAlert(title: String, message: String, okEvent: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            AnalyticsManager.shared.log(okEvent); completion?()
        })
        present(alert, animated: true)
    }
}
```

---

## 6. Implementation checklist

1. Add SDK packages (§1), `GoogleService-Info.plist`, git-ignored `Secrets.swift`, Crashlytics run script,
   SKAdNetwork IDs, ATT usage string, `-FIRDebugEnabled`.
2. Add the files in §4; fix every `// APP:` line.
3. Wire the launch order (§1) and `AnalyticsManager.isPremium`.
4. First launch: `LaunchPermissionManager.requestAll()` before onboarding.
5. Create `AppEvents` (§5) covering **every** screen, button, alert OK, sheet cancel, feature ok/fail, paywall entry.
6. Each VC: `AnalyticsManager.shared.logScreen(AppEvents.Screen.x)` in `viewDidAppear`.
7. Each button action: `AnalyticsManager.shared.log(AppEvents.Tap.x)` as the first line.
8. Each feature: `_ok` on success, `Outcome.xFail(for: error)` on failure.
9. Paywalls: adopt `IAPScreen`, call `IAPTracker` as in §4.8; hook `TrialTracker`/`RenewalTracker` into RevenueCat (§4.12).
10. Verify: Xcode console filter `EVENT_TRACK` (no `DROPPED` lines), Firebase DebugView, Facebook Events Manager
    test events, Clarity dashboard. Check taps/results are ≤ 31 chars and all other names ≤ 35.
