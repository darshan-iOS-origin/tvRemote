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

    #if DEBUG
    /// The Simulator's stand-in for the broadcast extension, while a test runs.
    private var testStream: MirrorTestStream?
    /// Where the test stream can be opened on the Mac (Safari, VLC). Shown on screen, never logged.
    private(set) var testStreamURL: URL?

    var isTestRunning: Bool {
        testStream != nil
    }
    #endif

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
        #if DEBUG
        // The Simulator test has no broadcast; leave it alone.
        if testStream != nil { return }
        #endif
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
        guard let status = MirrorShared.read(), status.isLive else { return }
        startTV(port: status.port, token: status.token)
    }

    private func startTV(port: UInt16, token: String) {
        guard task == nil else { return }
        state = .connectingTV
        beginBackgroundTask()
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.endBackgroundTask() }
            do {
                try await self.playOnTV(port: port, token: token)
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

        guard let url = Self.streamURL(port: port, token: token) else {
            throw CastMediaError.noWiFi
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

    /// The stream's address on this phone's Wi-Fi, or nil without one.
    private static func streamURL(port: UInt16, token: String) -> URL? {
        var phoneAddress = InterfaceSubnetProvider().currentSubnet().map { IPv4.string($0.address) }
        #if DEBUG
        // The Simulator on a wired Mac has no Wi-Fi address: use any private one (Android TV emulator testing).
        if phoneAddress == nil {
            phoneAddress = InterfaceSubnetProvider.anyPrivateAddress()
        }
        #endif
        guard let phoneAddress else { return nil }
        return URL(string: "http://\(phoneAddress):\(port)\(MirrorShared.playlistPath(token: token))")
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

    // MARK: - Simulator test (DEBUG)

    #if DEBUG
    /// Runs the test stream in the app and casts it to the connected TV, as if a broadcast had started.
    /// If the TV can't be reached, the stream keeps running so its address can still be opened on the Mac.
    func startSimulatorTest() {
        guard testStream == nil else { return }
        stopTV()
        let stream = MirrorTestStream()
        testStream = stream
        testStreamURL = nil
        state = .connectingTV
        LoggerManager.info("Mirror: Simulator test stream starting", category: "Mirror")
        stream.start(
            onReady: { [weak self] port in
                Task { @MainActor in self?.testStreamReady(stream, port: port) }
            },
            onFailure: { [weak self] in
                Task { @MainActor in
                    guard let self, self.testStream === stream else { return }
                    self.stopSimulatorTest()
                    self.state = .failed("The test stream stopped. Check the log for the encoder or server error.")
                }
            }
        )
    }

    func stopSimulatorTest() {
        testStream?.stop()
        testStream = nil
        testStreamURL = nil
        stopTV()
    }

    private func testStreamReady(_ stream: MirrorTestStream, port: UInt16) {
        guard testStream === stream else { return }
        testStreamURL = Self.streamURL(port: port, token: stream.token)
        LoggerManager.info("Mirror: Simulator test stream ready", category: "Mirror")
        startTV(port: port, token: stream.token)
    }
    #endif
}
