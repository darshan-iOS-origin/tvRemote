import Clarity
import UIKit

/// The one place that talks to Microsoft Clarity.
///
/// Call `configure()` once from `AppDelegate`. Initialization has to run on the main thread.
final class ClarityManager {

    static let shared = ClarityManager()

    private static let projectID = Secrets.clarityProjectID

    /// True after `ClaritySDK.initialize` has been attempted.
    private(set) var isConfigured = false

    /// True only when `ClaritySDK.initialize` succeeded, so events can be sent.
    private(set) var isStarted = false

    private init() {}

    /// Starts Clarity. Safe to call more than once. Hops to the main thread when it is not already there.
    func configure() {
        if Thread.isMainThread {
            start()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.start()
            }
        }
    }

    private func start() {
        guard !isConfigured else { return }
        #if DEBUG
        let logLevel = ClarityLogLevel.verbose
        #else
        let logLevel = ClarityLogLevel.none
        #endif
        let config = ClarityConfig(projectId: Self.projectID, logLevel: logLevel)
        let started = ClaritySDK.initialize(config: config)
        isConfigured = true
        isStarted = started
        if started {
            LoggerManager.success("Clarity configured", category: "Clarity")
            // The recording of this session can be opened from this link (look for it in the console).
            ClaritySDK.setOnSessionStartedCallback { _ in
                LoggerManager.info("Clarity session started: \(ClaritySDK.getCurrentSessionUrl() ?? "no url")", category: "Clarity")
            }
        } else {
            LoggerManager.error("Clarity did not start", category: "Clarity")
        }
    }
}
