import OneSignalExtension
import UserNotifications

/// Runs when a push has `mutable-content`. OneSignal attaches images, action buttons,
/// and confirmed-delivery data, then hands the notification back to iOS.
/// Shares App Group `group.com.tvremote.universal.smartcontrol.onesignal` with the app.
class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var receivedRequest: UNNotificationRequest?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        receivedRequest = request
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        OneSignalExtension.didReceiveNotificationExtensionRequest(
            request,
            with: bestAttemptContent,
            withContentHandler: contentHandler
        )
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler, let bestAttemptContent, let receivedRequest else { return }
        OneSignalExtension.serviceExtensionTimeWillExpireRequest(receivedRequest, with: bestAttemptContent)
        contentHandler(bestAttemptContent)
    }
}
