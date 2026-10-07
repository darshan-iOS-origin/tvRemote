//
//  SamsungTizenController.swift
//  tvRemoteDemo
//
//  Samsung Tizen (2016 and newer) over its WebSocket remote channel, using SmartCastKit's
//  `SamsungTizenClient` (https://github.com/yuri-rod/smart-tv-remote-swift, MIT, copyright 2026
//  Yuri Barreira). The first time, the TV shows an Allow prompt and then hands out a token. We keep
//  the token in the Keychain, so the next connection shows no prompt.
//
//  UNVERIFIED on a real TV: how a TV answers when the user chooses Deny. The library's first message
//  then carries no token, which we report as `TVError.denied`. A very old Tizen TV that never sends
//  a token would be reported the same way.
//

import Foundation
import SmartCastKit

nonisolated struct SamsungTizenController: TVController {
    let platform = TVPlatform.tizen

    private let host: String
    private let store: TVTokenStoring
    private let client: SamsungTizenClient
    private let approvalTimeout: TimeInterval
    private let http: HTTPRequesting

    init(
        host: String,
        store: TVTokenStoring = KeychainTokenStore(),
        http: HTTPRequesting = LocalHTTPClient(),
        approvalTimeout: TimeInterval = ApprovalWait.defaultTimeout
    ) {
        self.host = host
        self.store = store
        self.http = http
        self.approvalTimeout = approvalTimeout
        self.client = SamsungTizenClient(
            ip: host,
            appName: "TV Remote",
            token: store.token(for: host, platform: .tizen)
        )
        client.onTokenReceived = { [store, host] token in
            store.save(token, for: host, platform: .tizen)
        }
    }

    func connect() async throws {
        // SmartCastKit trusts any certificate it is shown. Only ever give it a local address.
        guard LocalTrustPolicy.shouldTrust(host: host) else {
            throw TVError.unreachable
        }
        defer { client.onStateChange = nil }
        do {
            try await ApprovalWait.wait(
                timeout: approvalTimeout,
                begin: { (emit: @escaping @Sendable (SamsungTizenClient.ConnectionState) -> Void) in
                    // Drop any earlier connection first, so a reconnect does not leave one open.
                    client.disconnect()
                    client.onStateChange = emit
                    client.connect()
                },
                judge: { state in
                    switch state {
                    case .connected(let token):
                        return token == nil ? .failure(.denied) : .success
                    case .failed:
                        return .failure(.unreachable)
                    case .disconnected, .connecting:
                        return .keepWaiting
                    }
                }
            )
        } catch {
            client.disconnect()
            throw error
        }
    }

    func send(_ key: KeyCommand) async throws {
        guard let remoteKey = Self.remoteKey(for: key) else {
            throw TVError.unsupportedKey(key)
        }
        try await perform { try await client.sendKey(remoteKey) }
    }

    /// Text uses SmartCastKit's `sendText` (`SendInputString`). No backspace code is known, so
    /// Backspace is not supported on Samsung for now.
    func send(_ text: TextCommand) async throws {
        switch text {
        case .insert(let string):
            guard !string.isEmpty else { return }
            try await perform { try await client.sendText(string) }
        case .backspace:
            throw TVError.unsupportedText
        case .enter:
            try await perform { try await client.sendKey(.enter) }
        }
    }

    /// Types the channel number on the TV's number keys, then Enter, with a short pause between keys.
    /// The key names are in SmartCastKit. UNVERIFIED that this tunes. A sub-channel (`7.1`) is not supported.
    func openChannel(_ number: String) async throws {
        guard ChannelNumber.isValid(number), number.allSatisfy({ ("0"..."9").contains($0) }) else {
            throw TVError.unsupportedCharacter
        }
        for character in number {
            guard let digit = character.wholeNumberValue else { continue }
            try await perform { try await client.sendKey(.number(digit)) }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        try await perform { try await client.sendKey(.enter) }
    }

    /// A fixed catalog: no source we can read lists a Samsung TV's installed apps.
    func apps() async throws -> [TVApp] {
        SamsungApps.catalog
    }

    /// `POST http://<ip>:8001/api/v2/applications/<id>` (TVCommanderKit). A 404 means the app is
    /// not installed.
    func launch(_ app: TVApp) async throws {
        guard LocalTrustPolicy.shouldTrust(host: host),
              let id = app.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "http://\(host):\(SamsungApps.port)/api/v2/applications/\(id)") else {
            throw TVError.unreachable
        }
        let response: HTTPResponse
        do {
            response = try await http.send(HTTPRequest(url: url, method: "POST", timeout: 5))
        } catch {
            throw ApprovalWait.tvError(from: error)
        }
        switch response.statusCode {
        case 200...299: return
        case 404: throw TVError.appUnavailable
        default: throw TVError.badResponse
        }
    }

    /// Runs a send. If the connection died since the last one, reconnects once and runs it again.
    private func perform(_ operation: () async throws -> Void) async throws {
        if case .connected = client.state {
            do {
                try await operation()
                return
            } catch {
                // The connection died since the last key. Reconnect below.
            }
        }
        try await connect()
        do {
            try await operation()
        } catch {
            throw ApprovalWait.tvError(from: error)
        }
    }

    /// Casts through the TV's DLNA renderer (DLNACastSession.swift). The known Samsung address is only a
    /// fallback for a TV that does not answer the search. UNVERIFIED on a real TV.
    func startCasting() async throws -> any CastSession {
        let session = DLNACastSession(
            host: host,
            fallbackControlURL: "http://\(host):9197/upnp/control/AVTransport1",
            http: http
        )
        try await session.open()
        return session
    }

    /// `GET http://<ip>:8001/api/v2/` describes the TV, with `device.wifiMac` (TVCommanderKit). UNVERIFIED
    /// on a real TV. Every MAC written anywhere in the reply is taken, so a changed field name still works.
    func hardwareAddresses() async -> [MACAddress] {
        guard LocalTrustPolicy.shouldTrust(host: host),
              let url = URL(string: "http://\(host):\(SamsungApps.port)/api/v2/"),
              let response = try? await http.send(HTTPRequest(url: url, method: "GET", timeout: 5)),
              (200...299).contains(response.statusCode) else {
            return []
        }
        return MACAddress.all(in: String(decoding: response.data, as: UTF8.self))
    }

    func disconnect() async {
        client.disconnect()
    }

    /// The library's key for a brand-neutral key. Its Tizen client turns each into a `KEY_*` code.
    static func remoteKey(for key: KeyCommand) -> RemoteKey? {
        switch key {
        case .power: return .power
        case .volumeUp: return .volumeUp
        case .volumeDown: return .volumeDown
        case .mute: return .mute
        case .channelUp: return .channelUp
        case .channelDown: return .channelDown
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .select: return .enter
        case .back: return .back
        case .home: return .home
        case .menu: return .menu
        case .rewind: return .rewind
        case .playPause: return .playPause
        case .fastForward: return .fastForward
        // The Google TV layout's keys. No code is confirmed for them on Samsung.
        // Tizen's TV key, from memory (it is not in SmartCastKit's own list): UNVERIFIED.
        case .liveTV: return .custom("KEY_TV")
        case .input, .settings, .guide, .hdmi1, .hdmi2, .hdmi3, .hdmi4: return nil
        // The library has play, pause, stop and info. The coloured keys, Exit and Subtitles are Samsung key
        // names from memory (UNVERIFIED; blue is `KEY_CYAN` on a Samsung remote). Next and Previous have none.
        case .play: return .play
        case .pause: return .pause
        case .stop: return .stop
        case .info: return .info
        case .red: return .custom("KEY_RED")
        case .green: return .custom("KEY_GREEN")
        case .yellow: return .custom("KEY_YELLOW")
        case .blue: return .custom("KEY_CYAN")
        case .exit: return .custom("KEY_EXIT")
        case .subtitles: return .custom("KEY_CAPTION")
        case .next, .previous: return nil
        // The library's number keys, the same ones the channel jump presses.
        case .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9:
            return key.digitValue.map { .number($0) }
        }
    }
}
