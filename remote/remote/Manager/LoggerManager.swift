import Foundation

public enum LogLevel: Int, CaseIterable {
    case verbose = 0
    case debug = 1
    case info = 2
    case success = 3
    case warning = 4
    case error = 5
    
    public var emoji: String {
        switch self {
        case .verbose: return "📋"
        case .debug:   return "🔍"
        case .info:    return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error:   return "❌"
        }
    }
    
    public var label: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug:   return "DEBUG"
        case .info:    return "INFO"
        case .success: return "SUCCESS"
        case .warning: return "WARNING"
        case .error:   return "ERROR"
        }
    }
}


public enum LoggerManager {
    
    public static var minimumLevel: LogLevel = .verbose
    /// Lines at or above this level are kept for the in-app log viewer (`LogsVC`), even in Release.
    public static var inAppMinimumLevel: LogLevel = .verbose
    public static var showFileLine: Bool = false
    public static var timeFormat: String = "HH:mm:ss.SSS"
    public static var defaultCategory: String? = nil
    
    private static let queue = DispatchQueue(label: "com.tvremote.universal.smartcontrol.loggermanager.serial")
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()
    
    
    private static func timestamp() -> String {
        dateFormatter.dateFormat = timeFormat
        return dateFormatter.string(from: Date())
    }
    
    public static func log(
        _ level: LogLevel,
        _ message: String,
        category: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let writesConsole = level.rawValue >= minimumLevel.rawValue
        let writesInApp = level.rawValue >= inAppMinimumLevel.rawValue
        guard writesConsole || writesInApp else { return }
        queue.async {
            let time = timestamp()
            let emoji = level.emoji
            let cat = category ?? defaultCategory
            var prefix = "\(time) \(emoji) [\(level.label)]"
            if let c = cat, !c.isEmpty { prefix += " \(c)" }
            if showFileLine {
                let fileName = (file as NSString).lastPathComponent
                prefix += " \(fileName):\(line)"
            }
            let output = "\(prefix) → \(message)"
            if writesConsole {
                print(output)
            }
            if writesInApp {
                AppLogStore.append(output)
            }
        }
    }
    
    public static func custom(
        emoji: String,
        label: String = "LOG",
        _ message: String,
        category: String? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        queue.async {
            let time = timestamp()
            let cat = category ?? defaultCategory
            var prefix = "\(time) \(emoji) [\(label)]"
            if let c = cat, !c.isEmpty { prefix += " \(c)" }
            if showFileLine {
                let fileName = (file as NSString).lastPathComponent
                prefix += " \(fileName):\(line)"
            }
            let output = "\(prefix) → \(message)"
            print(output)
            if LogLevel.debug.rawValue >= inAppMinimumLevel.rawValue {
                AppLogStore.append(output)
            }
        }
    }
    
    public static func verbose(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, message, category: category, file: file, function: function, line: line)
    }
    
    public static func debug(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, category: category, file: file, function: function, line: line)
    }
    
    public static func info(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, category: category, file: file, function: function, line: line)
    }
    
    public static func success(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.success, message, category: category, file: file, function: function, line: line)
    }
    
    public static func warning(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, category: category, file: file, function: function, line: line)
    }
    
    public static func error(_ message: String, category: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, category: category, file: file, function: function, line: line)
    }
    
    
    public static func printData(
        _ value: Any,
        emoji: String = "📦",
        label: String = "DATA",
        category: String? = nil,
        file: String = #file,
        line: Int = #line
    ) {
        let message: String
        if let arr = value as? [Any] {
            message = arr.map { "\($0)" }.joined(separator: ", ")
        } else if let dict = value as? [String: Any] {
            message = dict.map { "\($0.key): \($0.value)" }.sorted().joined(separator: ", ")
        } else {
            message = String(describing: value)
        }
        custom(emoji: emoji, label: label, message, category: category, file: file, line: line)
    }
    
    public static func dump(_ value: Any, category: String? = nil, file: String = #file, line: Int = #line) {
        printData(value, emoji: "🔍", label: "DEBUG", category: category, file: file, line: line)
    }
    
    
    public static func network(_ message: String, category: String? = nil, file: String = #file, line: Int = #line) {
        custom(emoji: "📤", label: "NETWORK", message, category: category, file: file, line: line)
    }
    
    public static func cache(_ message: String, category: String? = nil, file: String = #file, line: Int = #line) {
        custom(emoji: "💾", label: "CACHE", message, category: category, file: file, line: line)
    }
    
    public static func ui(_ message: String, category: String? = nil, file: String = #file, line: Int = #line) {
        custom(emoji: "🖼️", label: "UI", message, category: category, file: file, line: line)
    }
    
    public static func auth(_ message: String, category: String? = nil, file: String = #file, line: Int = #line) {
        custom(emoji: "🔐", label: "AUTH", message, category: category, file: file, line: line)
    }
    
    public static func analytics(_ message: String, category: String? = nil, file: String = #file, line: Int = #line) {
        custom(emoji: "📊", label: "ANALYTICS", message, category: category, file: file, line: line)
    }
    
    public static func prettyDump(
        _ message: String,
        label: String = "FEED",
        category: String? = "Network",
        file: String = #file,
        line: Int = #line
    ) {
        custom(emoji: "📋", label: label, message, category: category, file: file, line: line)
    }
}


extension LoggerManager {
    
    public static func updateTimeFormat() {
        queue.async {
            dateFormatter.dateFormat = timeFormat
        }
    }
}
