import AppTrackingTransparency
import AVFoundation
import Foundation
import Speech
import UserNotifications

/// One format for every system permission prompt.
///
/// A prompt that is actually shown logs `alert triggered`, then `allow` or `deny` with the status
/// iOS returned. A check that does not show an alert logs `no alert` plus that same choice and
/// status. The same result is logged once, so a later scan or voice tap does not repeat it.
enum PermissionLogger {

    private static let category = "Permission"
    private static let lock = NSLock()
    private static var lastResult: [String: String] = [:]

    static func triggered(_ name: String) {
        LoggerManager.info("\(name): alert triggered", category: category)
    }

    static func tracking(_ status: ATTrackingManager.AuthorizationStatus, prompted: Bool) {
        finished("Tracking", status: name(status), prompted: prompted)
    }

    static func notifications(_ status: UNAuthorizationStatus, prompted: Bool) {
        finished("Notifications", status: name(status), prompted: prompted)
    }

    static func microphone(_ permission: AVAudioSession.RecordPermission, prompted: Bool) {
        finished("Microphone", status: name(permission), prompted: prompted)
    }

    static func speech(_ status: SFSpeechRecognizerAuthorizationStatus, prompted: Bool) {
        finished("Speech Recognition", status: name(status), prompted: prompted)
    }

    static func localNetwork(_ result: LocalNetworkAuthorization, prompted: Bool) {
        finished("Local Network", status: name(result), prompted: prompted)
    }

    /// Used when the prompt callback and the system status disagree, so the logged choice still
    /// matches what the user tapped.
    static func notifications(accepted: Bool, prompted: Bool) {
        finished("Notifications", status: accepted ? "authorized" : "denied", prompted: prompted)
    }

    private static func finished(_ name: String, status: String, prompted: Bool) {
        let choice = choice(for: status)
        let decision = prompted ? choice : "no alert, \(choice)"
        let message = "\(name): \(decision) (\(status))"
        lock.lock()
        let duplicate = lastResult[name] == message
        if !duplicate {
            lastResult[name] = message
        }
        lock.unlock()
        guard !duplicate else { return }
        switch choice {
        case "allow":
            LoggerManager.success(message, category: category)
        case "deny", "restricted":
            LoggerManager.warning(message, category: category)
        default:
            LoggerManager.info(message, category: category)
        }
    }

    private static func choice(for status: String) -> String {
        switch status {
        case "authorized", "granted", "provisional", "ephemeral":
            return "allow"
        case "denied":
            return "deny"
        case "restricted":
            return "restricted"
        default:
            return "undetermined"
        }
    }

    private static func name(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }

    private static func name(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    private static func name(_ permission: AVAudioSession.RecordPermission) -> String {
        switch permission {
        case .undetermined: return "undetermined"
        case .denied: return "denied"
        case .granted: return "granted"
        @unknown default: return "unknown"
        }
    }

    private static func name(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }

    private static func name(_ result: LocalNetworkAuthorization) -> String {
        switch result {
        case .granted: return "granted"
        case .denied: return "denied"
        case .undetermined: return "undetermined"
        }
    }
}
