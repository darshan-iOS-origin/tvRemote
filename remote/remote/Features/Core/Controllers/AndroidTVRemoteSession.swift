//
//  AndroidTVRemoteSession.swift
//  tvRemoteDemo
//
//  One control connection to an Android / Google TV (port 6466): open it, run the configuration
//  handshake, then keep listening so pings are answered, and send keys. Messages: see
//  AndroidTVRemoteMessages.swift.
//

import Foundation

actor AndroidTVRemoteSession {
    /// The control port. Source: the protocol wiki and AndroidTVRemoteControl (see the messages file).
    static let port: UInt16 = 6466

    private let host: String
    private let connector: AndroidTVConnectionMaking
    private let timeout: TimeInterval

    private var connection: AndroidTVPairingConnection?
    private var buffer = PairingFrameBuffer()
    private var readerTask: Task<Void, Never>?
    /// Bumped on every open, so a listener that outlives its connection cannot touch a newer one.
    private var generation = 0
    private var isOpen = false
    /// How text is typed. Automatic unless a debug build forces a method.
    private(set) var textMethod = TextInputMethod.automatic
    /// The latest input-method counters the TV sent. A text edit must carry them. Zero until the TV
    /// has sent any, as in androidtvremote2.
    private var imeCounter = 0
    private var imeFieldCounter = 0
    /// The id of the voice session the TV last began, or nil if it has not (since the last request).
    private var pendingVoiceSession: Int?

    init(host: String, connector: AndroidTVConnectionMaking = NWAndroidTVConnector(), timeout: TimeInterval = 10) {
        self.host = host
        self.connector = connector
        self.timeout = timeout
    }

    var isConnected: Bool {
        isOpen
    }

    /// Opens the connection and runs the handshake. Throws a `TVError`.
    func open() async throws {
        close()

        let newConnection: AndroidTVPairingConnection
        do {
            newConnection = try connector.makeConnection(host: host, port: Self.port)
        } catch {
            throw Self.tvError(from: error)
        }

        do {
            try await newConnection.connect(timeout: timeout)
            try await handshake(over: newConnection)
        } catch {
            newConnection.close()
            buffer = PairingFrameBuffer()
            throw Self.tvError(from: error)
        }

        connection = newConnection
        isOpen = true
        generation += 1
        let current = generation
        readerTask = Task { await self.listen(on: newConnection, generation: current) }
    }

    // MARK: - Voice

    /// Asks the TV to start listening and returns the session id it gives, after answering it. Throws
    /// `TVError.voiceNotStarted` if the TV does not answer within two seconds.
    func startVoice() async throws -> Int {
        guard isOpen else { throw TVError.notConnected }
        pendingVoiceSession = nil
        try await send([AndroidTVRemoteMessages.assistantKeyFrame()])

        let deadline = Date().addingTimeInterval(2)
        while pendingVoiceSession == nil {
            guard Date() < deadline else {
                LoggerManager.warning("The TV did not begin a voice session", category: "AndroidTV")
                throw TVError.voiceNotStarted
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let id = pendingVoiceSession else { throw TVError.voiceNotStarted }
        try await send([AndroidTVRemoteMessages.voiceBeginFrame(sessionID: id)])
        return id
    }

    /// Sends audio for a voice session. Throws a `TVError`.
    func sendVoice(sessionID: Int, pcm: Data) async throws {
        try await send(AndroidTVRemoteMessages.voicePayloadFrames(sessionID: sessionID, pcm: pcm))
    }

    /// Tells the TV the voice session is over. A failure is ignored: the session is over anyway.
    func endVoice(sessionID: Int) async {
        pendingVoiceSession = nil
        try? await send([AndroidTVRemoteMessages.voiceEndFrame(sessionID: sessionID)])
    }

    /// The MAC addresses written in the TV's certificate, for Wake-on-LAN. The certificate's subject
    /// carries the TV's name and MAC address, as androidtvremote2 reads it. UNVERIFIED on a real
    /// device, and which field holds it is not relied on: every text that looks like a MAC address in
    /// the certificate is taken. Empty if there is none. Needs an open connection.
    func hardwareAddresses() -> [MACAddress] {
        guard let certificate = connection?.serverCertificate else { return [] }
        // Bytes that are not ASCII become spaces, so the text parts of the DER can be searched.
        let text = String(decoding: certificate.map { $0 < 0x80 ? $0 : 0x20 }, as: UTF8.self)
        return MACAddress.all(in: text)
    }

    func setTextMethod(_ method: TextInputMethod) {
        textMethod = method
    }

    /// Types text into the text field focused on the TV, using the latest counters the TV sent.
    /// Throws a `TVError`.
    func sendText(_ text: String) async throws {
        LoggerManager.debug(
            "Sending text edit: \(text.unicodeScalars.count) characters, ime=\(imeCounter) field=\(imeFieldCounter), open=\(isOpen)",
            category: "AndroidTV"
        )
        try await send([
            AndroidTVRemoteMessages.textFrame(text, imeCounter: imeCounter, fieldCounter: imeFieldCounter)
        ])
    }

    /// Sends messages in order. Throws a `TVError`, and closes the session if the write fails.
    func send(_ frames: [Data]) async throws {
        guard isOpen, let connection else {
            throw TVError.notConnected
        }
        do {
            for frame in frames {
                try await connection.send(frame)
            }
        } catch {
            close()
            throw Self.tvError(from: error)
        }
    }

    func close() {
        readerTask?.cancel()
        readerTask = nil
        connection?.close()
        connection = nil
        buffer = PairingFrameBuffer()
        isOpen = false
        imeCounter = 0
        imeFieldCounter = 0
    }

    // MARK: - Handshake

    private func handshake(over connection: AndroidTVPairingConnection) async throws {
        // 1. A paired phone gets the TV's configuration straight away. If the TV drops the
        //    connection instead, this phone is almost certainly not paired.
        do {
            try await waitForFrame(over: connection) { AndroidTVRemoteMessages.isServerConfiguration($0) }
        } catch PairingError.unreachable {
            throw TVError.notPaired
        }
        try await connection.send(AndroidTVRemoteMessages.configuration())

        // 2. The TV acknowledges with an empty field 2 message (`18, 0`).
        try await waitForFrame(over: connection) { AndroidTVRemoteMessages.isSetActive($0) }
        try await connection.send(AndroidTVRemoteMessages.secondConfiguration())
    }

    /// Reads until a message matching `isWanted` arrives. Other messages are skipped.
    private func waitForFrame(
        over connection: AndroidTVPairingConnection,
        matching isWanted: ([ProtoField]) -> Bool
    ) async throws {
        while true {
            while let frame = buffer.nextFrame() {
                if let fields = ProtoReader.fields(in: frame) {
                    noteInputMethodState(fields)
                    if isWanted(fields) {
                        return
                    }
                }
            }
            let chunk = try await connection.receive(timeout: timeout)
            buffer.append(chunk)
        }
    }

    // MARK: - Listening

    /// Reads for as long as the connection lives. The TV sends pings, and closes the connection if
    /// they go unanswered. Everything else it sends (power, current app, volume) is ignored.
    private func listen(on connection: AndroidTVPairingConnection, generation: Int) async {
        while !Task.isCancelled {
            do {
                while let frame = buffer.nextFrame() {
                    await answerIfPing(frame, on: connection)
                }
                let chunk = try await connection.receive(timeout: nil)
                buffer.append(chunk)
            } catch {
                markClosed(generation: generation)
                return
            }
        }
    }

    private func answerIfPing(_ frame: [UInt8], on connection: AndroidTVPairingConnection) async {
        guard let fields = ProtoReader.fields(in: frame) else { return }
        noteInputMethodState(fields)
        guard let value = AndroidTVRemoteMessages.pingValue(in: fields) else { return }
        // A failed write here surfaces on the next read or key press.
        try? await connection.send(AndroidTVRemoteMessages.pong(value: value))
    }

    /// Remembers the TV's latest input-method counters, which a text edit has to carry, and logs
    /// what the TV sent (field numbers and counters only, never the text of a field).
    private func noteInputMethodState(_ fields: [ProtoField]) {
        if let voiceSession = AndroidTVRemoteMessages.voiceSessionID(in: fields) {
            pendingVoiceSession = voiceSession
            LoggerManager.debug("TV began a voice session", category: "AndroidTV")
            return
        }
        if let update = AndroidTVRemoteMessages.inputMethodUpdate(in: fields) {
            if let ime = update.imeCounter {
                imeCounter = ime
            }
            if let field = update.fieldCounter {
                imeFieldCounter = field
            }
            LoggerManager.debug(
                "TV input method \(update.kind): \(update.detail); edits will use ime=\(imeCounter) field=\(imeFieldCounter)",
                category: "AndroidTV"
            )
        } else if let summary = AndroidTVRemoteMessages.summary(of: fields) {
            LoggerManager.debug("TV message: \(summary)", category: "AndroidTV")
        }
    }

    private func markClosed(generation: Int) {
        guard generation == self.generation else { return }
        close()
    }

    // MARK: - Errors

    private static func tvError(from error: Error) -> TVError {
        if let tvError = error as? TVError {
            return tvError
        }
        switch error as? PairingError {
        case .identityUnavailable: return .identityUnavailable
        case .timedOut: return .timedOut
        default: return .unreachable
        }
    }
}
