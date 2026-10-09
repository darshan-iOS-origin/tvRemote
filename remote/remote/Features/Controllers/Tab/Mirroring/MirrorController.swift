import UIKit

/// Runs broadcast mirroring on the app's side. The broadcast extension (`MirrorBroadcast`) captures the
/// screen and serves it as a live stream on this phone; when it says the stream is ready, this asks the
/// connected TV to play it over Google Cast, and when the broadcast stops, it ends the TV's session.
///
/// It lives as long as the app (`AppServices.mirror`), so a broadcast that starts while the Mirror screen is
/// closed still reaches the TV. It knows nothing about views: `ScreenMirrorVC` renders the `State`.
/// Addresses and the stream's token are never logged.
@MainActor
final class MirrorController {

    enum State: Equatable {
        case idle
        /// The stream is ready; the TV is being asked to play it.
        case connectingTV
        case mirroring
        case failed(String)
    }

    var onState: ((State) -> Void)?

    private(set) var state: State = .idle {
        didSet { onState?(state) }
    }

    private var cast: (any CastSession)?
    private var task: Task<Void, Never>?
    private var darwinObserver: DarwinNotificationObserver?
    private var activeObserver: NSObjectProtocol?
    private var didCheckLocalNetwork = false
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    init() {
        darwinObserver = DarwinNotificationObserver(
            names: [MirrorShared.readyNotification, MirrorShared.stoppedNotification]
        ) { [weak self] name in
            Task { @MainActor in self?.received(name) }
        }
        // Notifications can be missed while the app is suspended, so the shared state is checked again.
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncWithBroadcast() }
        }
    }

    /// True while the extension is broadcasting a stream.
    var isBroadcasting: Bool {
        MirrorShared.read()?.isLive ?? false
    }

    /// Brings the TV in line with the broadcast: starts it if the stream is live and the TV isn't playing
    /// it, and ends the TV's session if the broadcast is gone. A failed start is not retried here, so the
    /// error stays on screen until the user stops and starts the broadcast again.
    func syncWithBroadcast() {
        if isBroadcasting {
            if cast == nil, task == nil, !isFailed {
                startTV()
            }
        } else if cast != nil || task != nil || state == .mirroring || state == .connectingTV {
            stopTV()
        }
    }

    // MARK: - Private

    private func received(_ name: String) {
        switch name {
        case MirrorShared.readyNotification:
            LoggerManager.info("Mirror: the broadcast stream is ready", category: "Mirror")
            startTV()
        case MirrorShared.stoppedNotification:
            LoggerManager.info("Mirror: the broadcast stopped", category: "Mirror")
            stopTV()
        default:
            break
        }
    }

    private func startTV() {
        guard task == nil, let status = MirrorShared.read(), status.isLive else { return }
        state = .connectingTV
        beginBackgroundTask()
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.endBackgroundTask() }
            do {
                try await self.playOnTV(port: status.port, token: status.token)
                // A cancelled run was replaced by `stopTV()`, which already reset the state.
                guard !Task.isCancelled else { return }
                self.state = .mirroring
                LoggerManager.success("Mirror: the TV is playing the screen", category: "Mirror")
                HapticManager.trigger(.success)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self.fail(error)
            }
            self.task = nil
        }
    }

    private func playOnTV(port: UInt16, token: String) async throws {
        guard await AppServices.connection.activeDevice != nil else {
            throw CastFailure.notConnected
        }

        // The TV fetches the stream from this phone over the local network.
        #if !targetEnvironment(simulator)
        if !didCheckLocalNetwork {
            var authorizer = NWBrowserLocalNetworkAuthorizer()
            authorizer.timeout = 5
            let permission = await authorizer.requestAuthorization()
            guard permission != .denied else { throw CastFailure.localNetworkDenied }
            didCheckLocalNetwork = true
        }
        #endif

        guard let phoneAddress = InterfaceSubnetProvider().currentSubnet().map({ IPv4.string($0.address) }) else {
            throw CastMediaError.noWiFi
        }
        guard let url = URL(string: "http://\(phoneAddress):\(port)\(MirrorShared.playlistPath(token: token))") else {
            throw CastMediaError.serverFailed
        }
        try Task.checkCancellation()

        let session: any CastSession
        if let cast {
            session = cast
        } else {
            session = try await AppServices.connection.startCasting()
            cast = session
        }
        try Task.checkCancellation()
        try await session.playLive(url: url, title: "iPhone Screen")
    }

    /// The user may leave the app right after starting the broadcast: this keeps it running until the TV
    /// has been told.
    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Mirror") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func stopTV() {
        task?.cancel()
        task = nil
        let session = cast
        cast = nil
        if state != .idle, !isFailed {
            state = .idle
        } else {
            // The state is unchanged, but whether a broadcast runs did change: let the screen redraw.
            onState?(state)
        }
        if let session {
            Task { await session.close() }
        }
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func fail(_ error: Error) {
        LoggerManager.error("Mirror: failed: \(error)", category: "Mirror")
        HapticManager.trigger(.error)
        let session = cast
        cast = nil
        if let session {
            Task { await session.close() }
        }
        state = .failed(Self.message(for: error))
    }

    private static func message(for error: Error) -> String {
        switch error {
        case TVError.unsupportedCasting:
            return "This TV can't show the iPhone screen through this app. Try AirPlay if the TV has it."
        case TVError.castFailed:
            return "The TV could not play the screen. Check that it's on the same Wi-Fi, then try again."
        default:
            return CastController.message(for: error)
        }
    }
}
