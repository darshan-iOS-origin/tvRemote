import AppTrackingTransparency
import FacebookCore
import UIKit

/// The one place that talks to the Facebook SDK.
///
/// Call `configure(application:launchOptions:)` once from `AppDelegate`. App ID and client token
/// are set in code before the SDK starts. URL and universal-link callbacks come from `SceneDelegate`.
final class FacebookManager {

    static let shared = FacebookManager()

    private static let appID = "1107484785112726"
    private static let clientToken = "81f85d4e05b8d1685f8a5f024b0f4a7e"
    private static let displayName = "TV Control"

    /// True after `ApplicationDelegate` has been started.
    private(set) var isConfigured = false

    private init() {}

    /// Starts the Facebook SDK. Safe to call more than once.
    func configure(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !isConfigured else { return }
        Settings.shared.appID = Self.appID
        Settings.shared.clientToken = Self.clientToken
        Settings.shared.displayName = Self.displayName
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true
        #if DEBUG
        // The SDK's own log in the Xcode console: every app event it queues and every flush it sends to
        // Facebook (look for "FBSDKLog"), with the HTTP result.
        Settings.shared.enableLoggingBehavior(.appEvents)
        Settings.shared.enableLoggingBehavior(.networkRequests)
        Settings.shared.enableLoggingBehavior(.informational)
        #endif
        // Facebook is told whether it may use the advertising ID (IDFA) only through this flag; it is not
        // switched on by the ATT answer on its own. Set it from the current ATT answer now (returning users),
        // again right after the first-launch ATT prompt, and whenever the app comes forward (the user can
        // change the answer in iOS Settings).
        syncTrackingPermission()
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncTrackingPermission() }
        }
        _ = ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        isConfigured = true
        LoggerManager.success("Facebook SDK configured", category: "Facebook")
    }

    /// Tells Facebook whether the user allowed App Tracking Transparency. Only `.authorized` turns advertiser
    /// tracking on (and with it the IDFA in events); not determined, denied and restricted keep it off.
    /// Call it right after the ATT prompt is answered. Safe to call any time.
    @MainActor
    func syncTrackingPermission() {
        let allowed = ATTrackingManager.trackingAuthorizationStatus == .authorized
        guard Settings.shared.isAdvertiserTrackingEnabled != allowed else { return }
        Settings.shared.isAdvertiserTrackingEnabled = allowed
        LoggerManager.info("Facebook advertiser tracking \(allowed ? "on" : "off")", category: "Facebook")
    }

    /// Forwards an open-URL callback to the Facebook SDK.
    @discardableResult
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[.sourceApplication] as? String,
            annotation: options[.annotation]
        )
    }

    /// Forwards scene open-URL callbacks to the Facebook SDK.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            var options: [UIApplication.OpenURLOptionsKey: Any] = [:]
            if let sourceApplication = context.options.sourceApplication {
                options[.sourceApplication] = sourceApplication
            }
            if let annotation = context.options.annotation {
                options[.annotation] = annotation
            }
            application(UIApplication.shared, open: context.url, options: options)
        }
    }

    /// Forwards a universal-link callback to the Facebook SDK.
    @discardableResult
    func application(_ application: UIApplication, continue userActivity: NSUserActivity) -> Bool {
        ApplicationDelegate.shared.application(application, continue: userActivity)
    }
}
