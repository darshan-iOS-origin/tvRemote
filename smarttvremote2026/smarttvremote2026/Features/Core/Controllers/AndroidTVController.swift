//
//  AndroidTVController.swift
//  tvRemoteDemo
//
//  Android / Google TV control over the Android TV Remote v2 protocol (TLS, port 6466). The phone must
//  be paired first (see AndroidTVPairing). The connection is kept open between keys. The TV drops it
//  if it stops answering pings, so a dead connection is reopened once when a key is sent.
//

import Foundation

nonisolated struct AndroidTVController: TVController {
    let platform = TVPlatform.androidTV

    private let host: String
    private let session: AndroidTVRemoteSession

    init(host: String, connector: AndroidTVConnectionMaking = NWAndroidTVConnector(), timeout: TimeInterval = 10) {
        self.host = host
        self.session = AndroidTVRemoteSession(host: host, connector: connector, timeout: timeout)
    }

    func connect() async throws {
        try await session.open()
    }

    func send(_ key: KeyCommand) async throws {
        guard AndroidTVRemoteMessages.supports(key) else {
            throw TVError.unsupportedKey(key)
        }
        try await deliver(AndroidTVRemoteMessages.keyFrames(for: key))
    }

    func send(_ text: TextCommand) async throws {
        switch text {
        case .insert(let string):
            guard !string.isEmpty else { return }
            // Digits go as key presses, which are known to work. Letters and everything else go
            // through the TV's input method: in testing, letter key codes did not type, while
            // `adb shell input text` did. Debug builds can force either method.
            let method = await session.textMethod
            let onlyDigits = string.allSatisfy { ("0"..."9").contains($0) }
            let usesKeyPresses = method == .keyPresses || method == .keyTaps || (method == .automatic && onlyDigits)
            if usesKeyPresses {
                guard let frames = AndroidTVRemoteMessages.keyFrames(forText: string, asTaps: method == .keyTaps) else {
                    throw TVError.unsupportedCharacter
                }
                LoggerManager.debug("Typing \(string.count) characters as key presses (\(method))", category: "AndroidTV")
                try await deliver(frames)
            } else {
                LoggerManager.debug("Typing \(string.count) characters through the input method (\(method))", category: "AndroidTV")
                try await deliverText(string)
            }
        case .backspace:
            try await deliver(AndroidTVRemoteMessages.backspaceFrames())
        case .enter:
            try await deliver(AndroidTVRemoteMessages.enterFrames())
        }
    }

    /// Starts casting over Google Cast (port 8009), a second connection beside the remote's own.
    func startCasting() async throws -> any CastSession {
        let cast = GoogleCastSession(host: host)
        try await cast.open()
        return cast
    }

    /// Starts a voice session: the TV's own assistant listens to the phone's microphone.
    func startVoice() async throws -> any VoiceSession {
        if !(await session.isConnected) {
            try await session.open()
        }
        let id = try await session.startVoice()
        return AndroidTVVoiceSession(session: session, id: id)
    }

    func hardwareAddresses() async -> [MACAddress] {
        await session.hardwareAddresses()
    }

    func setTextInputMethod(_ method: TextInputMethod) async {
        await session.setTextMethod(method)
    }

    /// Types the channel number as key presses, then Enter. UNVERIFIED that this tunes: only a TV with
    /// a tuner and a Live TV app has channels. A Chromecast with Google TV has none.
    func openChannel(_ number: String) async throws {
        guard ChannelNumber.isValid(number), let digits = AndroidTVRemoteMessages.keyFrames(forText: number) else {
            throw TVError.unsupportedCharacter
        }
        try await deliver(digits + AndroidTVRemoteMessages.enterFrames())
    }

    /// A fixed catalog: the protocol cannot list the TV's apps.
    func apps() async throws -> [TVApp] {
        AndroidTVApps.catalog
    }

    func launch(_ app: TVApp) async throws {
        try await deliver([AndroidTVRemoteMessages.deepLinkFrame(url: app.id)])
    }

    /// Types through the TV's input method. A dead connection is reopened once.
    private func deliverText(_ text: String) async throws {
        if await session.isConnected {
            do {
                try await session.sendText(text)
                LoggerManager.debug("Text edit written to the TV", category: "AndroidTV")
                return
            } catch {
                LoggerManager.warning("Text edit failed, reopening the connection: \(error)", category: "AndroidTV")
            }
        } else {
            LoggerManager.warning("Session was closed before the text edit, reopening", category: "AndroidTV")
        }
        try await session.open()
        try await session.sendText(text)
        LoggerManager.debug("Text edit written to the TV after reopening", category: "AndroidTV")
    }

    private func deliver(_ frames: [Data]) async throws {
        guard !frames.isEmpty else { return }
        if await session.isConnected {
            do {
                try await session.send(frames)
                return
            } catch {
                // The connection died since the last key. Open a new one below.
            }
        }
        try await session.open()
        try await session.send(frames)
    }

    func disconnect() async {
        await session.close()
    }
}

/// One voice session with an Android / Google TV. The audio goes to the TV and nowhere else.
nonisolated struct AndroidTVVoiceSession: VoiceSession {
    let session: AndroidTVRemoteSession
    let id: Int

    func send(_ pcm: Data) async throws {
        try await session.sendVoice(sessionID: id, pcm: pcm)
    }

    func end() async {
        await session.endVoice(sessionID: id)
    }
}
