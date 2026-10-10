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
        let current = ATTrackingManager.trackingAuthorizationStatus
        guard current == .notDetermined else {
            PermissionLogger.tracking(current, prompted: false)
            return
        }
        PermissionLogger.triggered("Tracking")
        let status = await ATTrackingManager.requestTrackingAuthorization()
        PermissionLogger.tracking(status, prompted: true)
    }

    static func requestNotifications() async {
        if OneSignalManager.shared.isConfigured {
            _ = await OneSignalManager.shared.requestPermission()
            return
        }
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings().authorizationStatus
        guard current == .notDetermined else {
            PermissionLogger.notifications(current, prompted: false)
            return
        }
        PermissionLogger.triggered("Notifications")
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            let status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined {
                PermissionLogger.notifications(accepted: granted, prompted: true)
            } else {
                PermissionLogger.notifications(status, prompted: true)
            }
        } catch {
            LoggerManager.error(
                "Notifications: request failed (\(error.localizedDescription))",
                category: "Permission"
            )
        }
    }

    @MainActor
    private static func waitUntilActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
            break
        }
    }
}
