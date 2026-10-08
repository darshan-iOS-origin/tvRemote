import Foundation

extension Notification.Name {
    /// Posted on the main queue when a line is appended or the buffer is cleared.
    static let appLogStoreDidChange = Notification.Name("com.tvremote.universal.smartcontro.appLogStoreDidChange")
}

/// In-memory session log buffer for the in-app log viewer (`LogsVC`).
enum AppLogStore {
    private static let queue = DispatchQueue(label: "com.tvremote.universal.smartcontro.applogstore.serial")
    private static let maxLineCount = 5_000
    private static let maxByteCount = 512 * 1_024

    private static var lines: [String] = []
    private static var totalBytes = 0

    static func append(_ line: String) {
        queue.async {
            lines.append(line)
            totalBytes += line.utf8.count + 1
            trimIfNeeded()
            notifyChange()
        }
    }

    static func clear() {
        queue.async {
            lines.removeAll(keepingCapacity: false)
            totalBytes = 0
            notifyChange()
        }
    }

    static func snapshot() -> String {
        queue.sync {
            lines.joined(separator: "\n")
        }
    }

    private static func trimIfNeeded() {
        while lines.count > maxLineCount || totalBytes > maxByteCount, !lines.isEmpty {
            let removed = lines.removeFirst()
            totalBytes -= removed.utf8.count + 1
        }
    }

    private static func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .appLogStoreDidChange, object: nil)
        }
    }
}
