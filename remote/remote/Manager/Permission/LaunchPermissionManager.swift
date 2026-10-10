import AppTrackingTransparency
import UIKit
import UserNotifications

/// The permissions asked on the very first launch, one after the other: App Tracking Transparency,
/// then notifications. `requestAll()` returns only when both answers are in.
/// (Local Network access is asked on the scan screen: see `NWBrowserLocalNetworkAuthorizer`.)
enum LaunchPermissionManager {

    static func requestAll() async {
        await requestTracking()
        await requestNotifications()
    }

    /// iOS ignores the ATT request unless the app is active, so wait for that first.
    @MainActor
    static func requestTracking() async {
        await waitUntilActive()
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    static func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    @MainActor
    private static func waitUntilActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
            break
        }
    }
}
