import Foundation

/// Runs one time-boxed TV scan on top of `TVDiscoveryService` and logs when it starts and ends.
/// UI-free: callers receive each detected `TVDevice` through `onDevice` (main actor).
/// A TV can be reported more than once as the scan learns more about it, so callers de-duplicate by `host`.
@MainActor
final class TVScanner {

    static let defaultDuration: TimeInterval = 30

    private let service: TVDiscoveryService
    private let duration: TimeInterval
    private var task: Task<Void, Never>?

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    init(service: TVDiscoveryService = TVDiscoveryService(), duration: TimeInterval = TVScanner.defaultDuration) {
        self.service = service
        self.duration = duration
    }

    var isScanning: Bool { task != nil }

    /// Starts scanning for `duration` seconds. Does nothing while a scan is already running.
    func start(onDevice: @escaping @MainActor (TVDevice) -> Void, onFinish: (@MainActor () -> Void)? = nil) {
        guard task == nil else { return }

        let startedAt = Date()
        LoggerManager.info("Scan started at \(Self.timestamp(startedAt)) (duration \(Int(duration))s)", category: "Scan")

        let service = service
        let duration = duration
        task = Task { [weak self] in
            var count = 0
            for await tv in service.discover(timeout: duration) {
                if Task.isCancelled { break }
                LoggerManager.debug("Detected TV:\n\(tv.debugReport)", category: "Scan")
                count += 1
                onDevice(tv)
            }

            let endedAt = Date()
            let elapsed = endedAt.timeIntervalSince(startedAt)
            let reason = Task.isCancelled ? "stopped" : "finished"
            LoggerManager.info(
                "Scan ended at \(Self.timestamp(endedAt)) (\(reason), elapsed \(String(format: "%.1f", elapsed))s, \(count) detections)",
                category: "Scan"
            )
            self?.task = nil
            onFinish?()
        }
    }

    /// Stops a running scan. The end of the scan is logged by the scan task itself.
    func stop() {
        task?.cancel()
    }

    private static func timestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    deinit {
        task?.cancel()
    }
}
