//
//  VizioController.swift
//  tvRemoteDemo
//
//  Vizio SmartCast over its local HTTPS API. The TV is paired first (VizioPairing.swift), which gives an
//  AUTH_TOKEN kept in the Keychain. Every request then carries it as the `AUTH` header, and a key is
//  `PUT /key_command/` with `{"KEYLIST":[{"CODESET":n,"CODE":n,"ACTION":"KEYPRESS"}]}`.
//  The calls and codes follow heathbar/vizio-smart-cast, index.js (MIT, copyright 2017 Heath Paddock),
//  and the unofficial API notes by exiva. Only the request shapes and the numbers are used, no code.
//  The TV's certificate is self-signed, so it is only ever talked to on a private address.
//
//  UNVERIFIED on a real Vizio, the whole controller. The navigation, back, exit, menu, info, caption and
//  media codes have a single source.
//

import Foundation

nonisolated struct VizioController: TVController {
    let platform = TVPlatform.smartCast

    private let host: String
    private let client: HTTPRequesting
    private let store: TVTokenStoring
    private let timeout: TimeInterval
    /// The port that answered last, so a TV on the older firmware's port 9000 is not asked on 7345 every time.
    private let portMemory = PortMemory()

    init(
        host: String,
        client: HTTPRequesting = LocalHTTPClient(),
        store: TVTokenStoring = KeychainTokenStore(),
        timeout: TimeInterval = 4
    ) {
        self.host = host
        self.client = client
        self.store = store
        self.timeout = timeout
    }

    /// Checks that a token is saved and that the TV answers. Throws `TVError.notPaired` without a token.
    func connect() async throws {
        guard token() != nil else { throw TVError.notPaired }
        // Any answer on a Vizio port shows the TV is there. A key tells whether the token still works.
        _ = try await request(path: "state/device/power_mode", method: "GET", body: nil)
    }

    func send(_ key: KeyCommand) async throws {
        guard let code = Self.code(for: key) else {
            throw TVError.unsupportedKey(key)
        }
        let body = try Self.keyBody(codeset: code.codeset, code: code.code)
        let response = try await request(path: "key_command/", method: "PUT", body: body)
        guard Self.isSuccess(response.data) else {
            throw TVError.refused
        }
    }

    /// A Vizio SmartCast TV has Chromecast built in, so casting uses Google Cast on port 8009, as for an
    /// Android / Google TV. UNVERIFIED on a Vizio.
    func startCasting() async throws -> any CastSession {
        let cast = GoogleCastSession(host: host)
        try await cast.open()
        return cast
    }

    func disconnect() async {}

    // MARK: - Keys

    /// The (codeset, code) pair for a key, nil when the TV has no such key. Vizio has no Play / Pause
    /// toggle, no port keys (input only cycles), no number keys and no Live TV key.
    static func code(for key: KeyCommand) -> (codeset: Int, code: Int)? {
        switch key {
        case .power: return (11, 2)         // toggle; on is 11/1 and off is 11/0
        case .volumeUp: return (5, 1)
        case .volumeDown: return (5, 0)
        case .mute: return (5, 4)           // toggle; mute is 5/3 and unmute is 5/2
        case .channelUp: return (8, 1)
        case .channelDown: return (8, 0)
        case .input: return (7, 1)          // cycles through the inputs
        case .up: return (3, 8)
        case .down: return (3, 0)
        case .left: return (3, 1)
        case .right: return (3, 7)
        case .select: return (3, 2)
        case .back: return (4, 0)
        case .home: return (4, 3)           // the SmartCast (V) button
        case .menu: return (4, 8)
        case .info: return (4, 6)
        case .exit: return (9, 0)
        case .subtitles: return (4, 4)
        case .play: return (2, 3)
        case .pause: return (2, 2)
        case .rewind: return (2, 1)         // seek back
        case .fastForward: return (2, 0)    // seek forward
        case .playPause, .stop, .next, .previous, .red, .green, .yellow, .blue, .guide, .settings,
             .hdmi1, .hdmi2, .hdmi3, .hdmi4, .liveTV,
             .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9:
            return nil
        }
    }

    /// The body of one key press. Public for checking.
    static func keyBody(codeset: Int, code: Int) throws -> Data {
        let body: [String: Any] = [
            "KEYLIST": [["CODESET": codeset, "CODE": code, "ACTION": "KEYPRESS"] as [String: Any]]
        ]
        do {
            return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        } catch {
            throw TVError.badResponse
        }
    }

    /// True when the TV's answer says `SUCCESS`.
    static func isSuccess(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["STATUS"] as? [String: Any],
              let result = status["RESULT"] as? String else {
            return false
        }
        return result.uppercased() == "SUCCESS"
    }

    // MARK: - Requests

    private func token() -> String? {
        store.token(for: host, platform: .smartCast)
    }

    /// Sends a request on the port that answered last, then the others. A 401 or 403 means the token was
    /// revoked (the TV was reset), so the phone has to pair again.
    private func request(path: String, method: String, body: Data?) async throws -> HTTPResponse {
        guard LocalTrustPolicy.shouldTrust(host: host) else { throw TVError.unreachable }
        guard let token = token() else { throw TVError.notPaired }

        var ports = VizioPairing.ports
        if let remembered = portMemory.value, let index = ports.firstIndex(of: remembered) {
            ports.remove(at: index)
            ports.insert(remembered, at: 0)
        }

        var lastError = TVError.unreachable
        for port in ports {
            guard let url = URL(string: "https://\(host):\(port)/\(path)") else { continue }
            var headers = ["AUTH": token]
            if body != nil { headers["Content-Type"] = "application/json" }
            let request = HTTPRequest(url: url, method: method, headers: headers, body: body, timeout: timeout)
            let response: HTTPResponse
            do {
                response = try await client.send(request)
            } catch let error as URLError where error.code == .timedOut {
                lastError = .timedOut
                continue
            } catch {
                lastError = .unreachable
                continue
            }
            portMemory.value = port
            if response.statusCode == 401 || response.statusCode == 403 {
                throw TVError.notPaired
            }
            return response
        }
        throw lastError
    }
}

/// The last port that answered, shared by the copies of the controller. Safe across threads.
private nonisolated final class PortMemory: @unchecked Sendable {
    private let lock = NSLock()
    private var port: UInt16?

    var value: UInt16? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return port
        }
        set {
            lock.lock()
            port = newValue
            lock.unlock()
        }
    }
}
