import UIKit

/// Animates trailing dots on a label: "Text." → "Text.." → "Text..." and repeats.
@MainActor
final class DotAnimator {

    private var task: Task<Void, Never>?

    var isRunning: Bool { task != nil }

    func start(on label: UILabel, baseText: String, interval: TimeInterval = 0.5, maxDots: Int = 3) {
        stop()
        guard maxDots > 0 else { return }
        task = Task { [weak label] in
            var dots = 1
            while !Task.isCancelled {
                label?.text = baseText + String(repeating: ".", count: dots)
                dots = dots % maxDots + 1
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Stops the animation and, when given, puts `text` back on the label.
    func stop(restoring text: String? = nil, on label: UILabel? = nil) {
        task?.cancel()
        task = nil
        if let text { label?.text = text }
    }

    deinit {
        task?.cancel()
    }
}
