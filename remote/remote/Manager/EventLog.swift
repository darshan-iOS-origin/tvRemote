import Foundation

/// One console format for every event sent to an analytics SDK, so a single word finds them all.
///
/// In Xcode's console filter type `EVENT_TRACK` to see only events (or `EVENT_TRACK | Firebase`,
/// `EVENT_TRACK | Facebook`, `EVENT_TRACK | Clarity` for one SDK; `DROPPED` for events that were not sent).
/// Line shape: `📊 EVENT_TRACK | 🔥 Firebase | screen_splash`.
enum EventLog {

    enum Sink {
        case firebase, facebook, clarity

        var emoji: String {
            switch self {
            case .firebase: return "🔥"
            case .facebook: return "📘"
            case .clarity: return "🔭"
            }
        }

        var name: String {
            switch self {
            case .firebase: return "Firebase"
            case .facebook: return "Facebook"
            case .clarity: return "Clarity"
            }
        }

        var category: String { name }
    }

    static let tag = "📊 EVENT_TRACK"

    /// The event was handed to the SDK.
    static func sent(_ sink: Sink, _ name: String, details: String = "") {
        LoggerManager.success("\(tag) | \(sink.emoji) \(sink.name) | \(name)\(details)", category: sink.category)
    }

    /// The event was not sent, with the reason.
    static func dropped(_ sink: Sink, _ name: String, reason: String) {
        LoggerManager.error("\(tag) | \(sink.emoji) \(sink.name) | DROPPED \(name): \(reason)", category: sink.category)
    }
}
