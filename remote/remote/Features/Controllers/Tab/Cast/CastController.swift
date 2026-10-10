import PhotosUI
import UIKit

/// Why a cast could not start or continue, beyond the errors the core already has.
enum CastFailure: Error, Equatable {
    /// No TV is connected.
    case notConnected
    /// The user did not allow Local Network access, so the TV could not reach this phone.
    case localNetworkDenied
    /// A picked file is bigger than the limit.
    case fileTooLarge
}

/// Runs a cast: prepares the picked files, starts the phone's web server, opens the TV's cast session and
/// plays the queue. It owns the server, the temporary files and the session, and cleans them all up in
/// `finish()`. It knows nothing about views: `CastVC` renders the `State` it reports.
///
/// Threading: this class is `@MainActor`. File preparation runs off the main thread, the server has its own
/// queue and the cast session is an actor. One `Task` at a time; a new request is refused while one runs.
/// File names and addresses are never logged.
@MainActor
final class CastController {

    enum State: Equatable {
        case idle
        /// Working on something: preparing files, opening the session, sending to the TV.
        case busy(String)
        case playing(index: Int, count: Int, kind: CastMediaKind, isPaused: Bool)
        case failed(String)
    }

    // MARK: - Limits

    /// Most photos and videos taken from one pick.
    static let maxPhotosAndVideos = 10
    /// Most songs taken from one pick.
    static let maxSongs = 10
    /// Most files in the queue.
    static let maxQueue = 20
    /// Biggest single file, in bytes.
    static let maxFileBytes: Int64 = 2 * 1024 * 1024 * 1024

    // MARK: - Reporting

    var onState: ((State) -> Void)?
    /// Called once when the Local Network permission turns out to be denied.
    var onLocalNetworkDenied: (() -> Void)?
    /// Called when there is no connected TV.
    var onNotConnected: (() -> Void)?

    private(set) var state: State = .idle {
        didSet { onState?(state) }
    }

    /// True while a request is running. New picks and taps are refused until it ends.
    var isBusy: Bool {
        if case .busy = state { return true }
        return false
    }

    // MARK: - Private state

    private let server = LocalMediaServer()
    private let preparer = MediaPreparer()
    private var cast: (any CastSession)?
    private var queue: [CastMedia] = []
    private var paths: [UUID: String] = [:]
    private var index = 0
    private var isPaused = false
    private var address = ""
    private var port: UInt16 = 0
    private var task: Task<Void, Never>?
    private var didCheckLocalNetwork = false

    // MARK: - Casting

    /// Casts photos and videos from the photo picker.
    func cast(_ results: [PHPickerResult]) {
        guard !isBusy, !results.isEmpty else { return }
        let picked = Array(results.prefix(Self.maxPhotosAndVideos))
        if results.count > picked.count { HapticManager.trigger(.warning) }
        LoggerManager.info("Cast: \(picked.count) photo/video item(s) picked", category: "Cast")
        let preparer = self.preparer
        begin {
            var media: [CastMedia] = []
            for result in picked {
                try Task.checkCancellation()
                media.append(try await preparer.prepare(result))
            }
            return media
        }
    }

    /// Casts songs from the Files picker.
    func cast(musicAt urls: [URL]) {
        guard !isBusy, !urls.isEmpty else { return }
        let picked = Array(urls.prefix(Self.maxSongs))
        if urls.count > picked.count { HapticManager.trigger(.warning) }
        LoggerManager.info("Cast: \(picked.count) song(s) picked", category: "Cast")
        let preparer = self.preparer
        begin {
            var media: [CastMedia] = []
            for url in picked {
                try Task.checkCancellation()
                // The copy can be large, so it is done off the main thread.
                media.append(try await Task.detached { try preparer.prepareMusic(at: url) }.value)
            }
            return media
        }
    }

    func step(by offset: Int) {
        guard !isBusy else { return }
        let target = index + offset
        guard queue.indices.contains(target) else { return }
        index = target
        run { try await self.playCurrent() }
    }

    func togglePause() {
        guard !isBusy, let cast else { return }
        let wasPaused = isPaused
        run {
            if wasPaused {
                try await cast.resume()
            } else {
                try await cast.pause()
            }
            self.isPaused = !wasPaused
            LoggerManager.info("Cast: \(wasPaused ? "resumed" : "paused")", category: "Cast")
            self.showPlaying()
        }
    }

    func stopPlaying() {
        guard let cast else { return }
        task?.cancel()
        task = Task { [weak self] in
            try? await cast.stop()
            LoggerManager.info("Cast: stopped", category: "Cast")
            self?.queue = []
            self?.paths = [:]
            self?.state = .idle
        }
    }

    /// Ends the cast, stops the server and deletes the temporary files. Safe to call more than once.
    func finish() {
        task?.cancel()
        task = nil
        let session = cast
        cast = nil
        server.stop()
        preparer.removeAll()
        queue = []
        paths = [:]
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await session?.close() }
        LoggerManager.info("Cast: finished, server stopped and temporary files removed", category: "Cast")
    }

    // MARK: - Steps

    /// Prepares the picked files, makes sure the phone and the TV are ready, then plays the first one.
    private func begin(_ prepare: @escaping () async throws -> [CastMedia]) {
        state = .busy("Preparing…")
        task?.cancel()
        task = Task { [weak self] in
            do {
                let media = try await prepare()
                try Task.checkCancellation()
                guard let self else { return }
                for item in media where Self.fileSize(of: item.fileURL) > Self.maxFileBytes {
                    throw CastFailure.fileTooLarge
                }
                try await self.makeReady()
                self.queue = Array(media.prefix(Self.maxQueue))
                self.paths = [:]
                self.index = 0
                try await self.playCurrent()
            } catch is CancellationError {
                // A newer request or Back replaced this one.
            } catch {
                self?.fail(error)
            }
        }
    }

    /// Runs one more step of a cast that is already open, reporting any failure.
    private func run(_ work: @escaping () async throws -> Void) {
        task?.cancel()
        task = Task { [weak self] in
            do {
                try await work()
            } catch is CancellationError {
            } catch {
                self?.fail(error)
            }
        }
    }

    private func makeReady() async throws {
        guard await AppServices.connection.activeDevice != nil else {
            throw CastFailure.notConnected
        }

        // The TV fetches the file from this phone over the local network, so that permission is needed. On a
        // device the system prompt shows the first time. The Simulator has no such prompt, so it is skipped
        // there (the check would only add a wait).
        #if !targetEnvironment(simulator)
        if !didCheckLocalNetwork {
            var authorizer = NWBrowserLocalNetworkAuthorizer()
            authorizer.timeout = 5
            let permission = await authorizer.requestAuthorization()
            guard permission != .denied else { throw CastFailure.localNetworkDenied }
            didCheckLocalNetwork = true
        }
        #endif

        var phoneAddress = InterfaceSubnetProvider().currentSubnet().map { IPv4.string($0.address) }
        #if DEBUG
        // The Simulator on a wired Mac has no Wi-Fi address: use any private one (Android TV emulator testing).
        if phoneAddress == nil {
            phoneAddress = InterfaceSubnetProvider.anyPrivateAddress()
        }
        #endif
        guard let phoneAddress else { throw CastMediaError.noWiFi }
        address = phoneAddress

        port = try await server.start()
        LoggerManager.info("Cast: server listening on port \(port)", category: "Cast")

        if cast == nil {
            cast = try await AppServices.connection.startCasting()
            LoggerManager.info("Cast: session opened", category: "Cast")
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func playCurrent() async throws {
        guard let cast, queue.indices.contains(index) else { return }
        let media = queue[index]
        let path = paths[media.id] ?? server.register(fileURL: media.fileURL, contentType: media.contentType)
        paths[media.id] = path
        guard let url = URL(string: "http://\(address):\(port)\(path)") else {
            throw CastMediaError.serverFailed
        }
        state = .busy("Sending to the TV…")
        try await cast.play(url: url, contentType: media.contentType, title: media.title)
        isPaused = false
        LoggerManager.success("Cast: playing item \(index + 1) of \(queue.count)", category: "Cast")
        HapticManager.trigger(.success)
        showPlaying()
    }

    private func showPlaying() {
        guard queue.indices.contains(index) else {
            state = .idle
            return
        }
        state = .playing(index: index, count: queue.count, kind: queue[index].kind, isPaused: isPaused)
    }

    private func fail(_ error: Error) {
        LoggerManager.error("Cast: failed: \(error)", category: "Cast")
        HapticManager.trigger(.error)
        switch error as? CastFailure {
        case .notConnected:
            state = .idle
            onNotConnected?()
        case .localNetworkDenied:
            // The screen offers "Open Settings" instead of a plain alert.
            state = .idle
            onLocalNetworkDenied?()
        default:
            state = .failed(Self.message(for: error))
        }
    }

    // MARK: - Messages

    static func message(for error: Error) -> String {
        switch error {
        case let failure as CastFailure:
            switch failure {
            case .notConnected: return "No TV is connected."
            case .localNetworkDenied: return "Local Network access is off. Turn it on in Settings so the TV can reach this phone."
            case .fileTooLarge: return "That file is too large to cast (limit 2 GB)."
            }
        case let media as CastMediaError:
            switch media {
            case .noWiFi: return "Connect this phone to Wi-Fi, on the same network as the TV."
            case .serverFailed: return "Could not start sharing from this phone. Please try again."
            case .preparationFailed: return "That file could not be read or converted. Try another one."
            }
        case let tv as TVError:
            return tv.userMessage
        case let pairing as PairingError:
            return pairing.userMessage
        default:
            return TVError.unreachable.userMessage
        }
    }

    private static func fileSize(of url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
}
