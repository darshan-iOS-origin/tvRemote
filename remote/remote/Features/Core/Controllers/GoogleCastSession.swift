//
//  GoogleCastSession.swift
//  tvRemoteDemo
//
//  One Google Cast connection to a Chromecast, Google TV or Android TV (TLS, port 8009): open it,
//  start the TV's Default Media Receiver, tell it which web address to play, and control playback.
//  Messages: see GoogleCastMessages.swift. Written from pychromecast (MIT), no code copied.
//
//  Flow: CONNECT to the TV, answer its PING with PONG (and ping it every 5 s), LAUNCH the receiver
//  app, read RECEIVER_STATUS for the app's transportId and sessionId, CONNECT to the transport,
//  then LOAD on the media namespace and use the mediaSessionId from MEDIA_STATUS for PLAY, PAUSE
//  and STOP.
//
//  UNVERIFIED on a real TV: the whole flow, and that STOP on the receiver namespace sends the TV home.
//  File names and addresses are never logged, only message types.
//

import Foundation

actor GoogleCastSession: CastSession {
    static let port: UInt16 = 8009

    private let host: String
    private let connector: AndroidTVConnectionMaking
    private let timeout: TimeInterval

    private var connection: AndroidTVPairingConnection?
    private var buffer: [UInt8] = []
    private var readerTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var generation = 0
    private var requestCounter = 0
    private var isOpen = false

    // What the TV has told us.
    private var transportID: String?
    private var sessionID: String?
    private var mediaSessionID: Int?
    private var failure: String?
    private var launchFailed = false

    init(host: String, connector: AndroidTVConnectionMaking = NWAndroidTVConnector(), timeout: TimeInterval = 10) {
        self.host = host
        self.connector = connector
        self.timeout = timeout
    }

    // MARK: - Opening

    /// Connects and starts the media receiver on the TV. Throws a `TVError`.
    func open() async throws {
        teardown()

        let newConnection: AndroidTVPairingConnection
        do {
            newConnection = try connector.makeConnection(host: host, port: Self.port)
            try await newConnection.connect(timeout: timeout)
        } catch {
            throw Self.tvError(from: error)
        }
        connection = newConnection
        isOpen = true
        generation += 1
        let current = generation
        readerTask = Task { await self.listen(on: newConnection, generation: current) }
        heartbeatTask = Task { await self.beat(generation: current) }

        transportID = nil
        sessionID = nil
        launchFailed = false
        do {
            try await send(namespace: GoogleCastMessages.connectionNamespace, to: GoogleCastMessages.platformID, ["type": "CONNECT"])
            try await send(
                namespace: GoogleCastMessages.receiverNamespace,
                to: GoogleCastMessages.platformID,
                ["type": "LAUNCH", "appId": GoogleCastMessages.defaultMediaReceiver, "requestId": nextRequestID()]
            )
            try await wait(seconds: 15) { self.transportID != nil || self.launchFailed }
            guard let transport = transportID, !launchFailed else {
                throw TVError.castFailed
            }
            try await send(namespace: GoogleCastMessages.connectionNamespace, to: transport, ["type": "CONNECT"])
        } catch {
            teardown()
            throw Self.tvError(from: error)
        }
        LoggerManager.debug("Cast: the media receiver is running", category: "Cast")
    }

    // MARK: - Playing

    func play(url: URL, contentType: String, title: String) async throws {
        guard isOpen, let transport = transportID, let session = sessionID else {
            throw TVError.notConnected
        }
        mediaSessionID = nil
        failure = nil
        let media: [String: Any] = [
            "contentId": url.absoluteString,
            "contentType": contentType,
            "streamType": "BUFFERED",
            "metadata": ["metadataType": 0, "title": title] as [String: Any]
        ]
        try await send(
            namespace: GoogleCastMessages.mediaNamespace,
            to: transport,
            [
                "type": "LOAD",
                "requestId": nextRequestID(),
                "sessionId": session,
                "media": media,
                "autoplay": true,
                "currentTime": 0,
                "customData": [String: Any]()
            ]
        )
        LoggerManager.debug("Cast: asked the TV to load media", category: "Cast")
        do {
            try await wait(seconds: 20) { self.mediaSessionID != nil || self.failure != nil }
        } catch {
            throw TVError.castFailed
        }
        if let failure {
            LoggerManager.warning("Cast: the TV could not play it (\(failure))", category: "Cast")
            throw TVError.castFailed
        }
        guard mediaSessionID != nil else { throw TVError.castFailed }
    }

    func pause() async throws {
        try await control("PAUSE")
    }

    func resume() async throws {
        try await control("PLAY")
    }

    func stop() async throws {
        try await control("STOP")
    }

    private func control(_ type: String) async throws {
        guard isOpen, let transport = transportID, let session = sessionID, let media = mediaSessionID else {
            throw TVError.notConnected
        }
        try await send(
            namespace: GoogleCastMessages.mediaNamespace,
            to: transport,
            ["type": type, "mediaSessionId": media, "requestId": nextRequestID(), "sessionId": session]
        )
    }

    /// Ends the session: the TV leaves the media receiver and goes back to its home screen.
    func close() async {
        if isOpen, let session = sessionID {
            try? await send(
                namespace: GoogleCastMessages.receiverNamespace,
                to: GoogleCastMessages.platformID,
                ["type": "STOP", "sessionId": session, "requestId": nextRequestID()]
            )
            if let transport = transportID {
                try? await send(namespace: GoogleCastMessages.connectionNamespace, to: transport, ["type": "CLOSE"])
            }
        }
        teardown()
    }

    // MARK: - Reading

    private func listen(on connection: AndroidTVPairingConnection, generation: Int) async {
        while !Task.isCancelled {
            do {
                let chunk = try await connection.receive(timeout: nil)
                buffer.append(contentsOf: chunk)
                for message in GoogleCastMessages.decode(&buffer) {
                    await handle(message)
                }
            } catch {
                closed(generation: generation)
                return
            }
        }
    }

    private func handle(_ message: CastIncoming) async {
        guard let object = message.object, let type = object["type"] as? String else { return }
        switch message.namespace {
        case GoogleCastMessages.heartbeatNamespace:
            if type == "PING" {
                try? await send(namespace: GoogleCastMessages.heartbeatNamespace, to: message.source, ["type": "PONG"])
            }
        case GoogleCastMessages.receiverNamespace:
            if type == "RECEIVER_STATUS" {
                let status = object["status"] as? [String: Any]
                let apps = status?["applications"] as? [[String: Any]] ?? []
                if let app = apps.first(where: { $0["appId"] as? String == GoogleCastMessages.defaultMediaReceiver }) {
                    transportID = app["transportId"] as? String
                    sessionID = app["sessionId"] as? String
                }
            } else if type == "LAUNCH_ERROR" {
                launchFailed = true
                LoggerManager.warning("Cast: the TV could not start its media receiver", category: "Cast")
            }
        case GoogleCastMessages.mediaNamespace:
            if type == "MEDIA_STATUS" {
                let statuses = object["status"] as? [[String: Any]] ?? []
                if let status = statuses.first {
                    if let id = status["mediaSessionId"] as? Int {
                        mediaSessionID = id
                    }
                    if status["playerState"] as? String == "IDLE", let reason = status["idleReason"] as? String, reason == "ERROR" {
                        failure = "idle: error"
                    }
                }
            } else if ["LOAD_FAILED", "LOAD_CANCELLED", "INVALID_REQUEST", "INVALID_PLAYER_STATE"].contains(type) {
                failure = type
            }
        case GoogleCastMessages.connectionNamespace:
            if type == "CLOSE" {
                LoggerManager.debug("Cast: the TV closed the channel", category: "Cast")
            }
        default:
            break
        }
    }

    /// The TV expects a ping now and then, or it closes the connection.
    private func beat(generation: Int) async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard generation == self.generation, isOpen else { return }
            try? await send(namespace: GoogleCastMessages.heartbeatNamespace, to: GoogleCastMessages.platformID, ["type": "PING"])
        }
    }

    private func closed(generation: Int) {
        guard generation == self.generation else { return }
        teardown()
    }

    // MARK: - Helpers

    private func send(namespace: String, to destination: String, _ payload: [String: Any]) async throws {
        guard isOpen, let connection, let frame = GoogleCastMessages.frame(destination: destination, namespace: namespace, payload: payload) else {
            throw TVError.notConnected
        }
        do {
            try await connection.send(frame)
        } catch {
            teardown()
            throw Self.tvError(from: error)
        }
    }

    private func nextRequestID() -> Int {
        requestCounter += 1
        return requestCounter
    }

    /// Waits until `condition` is true, polling, or throws `TVError.timedOut`.
    private func wait(seconds: TimeInterval, until condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            guard Date() < deadline, isOpen else { throw TVError.timedOut }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func teardown() {
        readerTask?.cancel()
        heartbeatTask?.cancel()
        readerTask = nil
        heartbeatTask = nil
        connection?.close()
        connection = nil
        buffer = []
        isOpen = false
        transportID = nil
        sessionID = nil
        mediaSessionID = nil
    }

    private static func tvError(from error: Error) -> TVError {
        if let tvError = error as? TVError {
            return tvError
        }
        switch error as? PairingError {
        case .timedOut: return .timedOut
        default: return .unreachable
        }
    }
}
