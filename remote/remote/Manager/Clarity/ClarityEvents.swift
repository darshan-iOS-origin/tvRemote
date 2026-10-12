import Clarity
import Foundation

/// The one place that sends events to Microsoft Clarity.
///
/// Only screen events and IAP-related events go to Clarity (IAP entry points, the IAP flow, free trial and
/// renewal events, and the IAP alert/Premium-activated taps), always with the same name Firebase receives.
/// Events carry no parameters. `AnalyticsManager` decides what is sent; nothing else should call this.
/// Clarity does not read the advertising ID, so it needs no App Tracking Transparency answer.
final class ClarityEvents {

    static let shared = ClarityEvents()

    private static let category = "Clarity"

    /// Clarity accepts custom event values up to 254 characters.
    private static let maxValueLength = 254

    private init() {}

    /// Sends one custom event. Does nothing until Clarity has really started. Returns whether it was handed
    /// to the SDK (Clarity still drops it if no session is running yet).
    @discardableResult
    func log(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= Self.maxValueLength else {
            LoggerManager.error("Clarity event \(name) dropped: name must be 1-\(Self.maxValueLength) characters", category: Self.category)
            return false
        }
        guard ClarityManager.shared.isStarted else {
            LoggerManager.error("Clarity event \(name) dropped: Clarity is not started", category: Self.category)
            return false
        }
        ClaritySDK.sendCustomEvent(value: name)
        LoggerManager.success("Clarity event logged: \(name)", category: Self.category)
        return true
    }

    /// A screen event: names the screen in the session recording and sends the same event.
    func logScreen(_ name: String) {
        guard ClarityManager.shared.isStarted else {
            LoggerManager.error("Clarity screen \(name) dropped: Clarity is not started", category: Self.category)
            return
        }
        ClaritySDK.setCurrentScreenName(name)
        log(name)
    }
}
