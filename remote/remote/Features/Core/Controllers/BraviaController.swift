//
//  BraviaController.swift
//  tvRemoteDemo
//
//  Sony Bravia over its IP control (HTTP on port 80), for a Bravia that is not controlled through the
//  Android TV remote. The TV is signed in first (SonyPairing.swift), which gives an `auth` cookie kept in the
//  Keychain and sent with every request. Messages: BraviaMessages.swift.
//
//  Keys are IRCC codes. The codes are not hardcoded: the TV lists its own, name to code, and each of our
//  keys has a short list of Sony's usual names; the first one the TV has is sent. The names are from memory.
//
//  UNVERIFIED on a real Sony, the whole controller. Source of the calls: pybravia (MIT), sony_bravia_psk
//  (MIT), bravia-auth-and-remote (ISC); no code is copied.
//

import Foundation

nonisolated struct BraviaController: TVController {
    let platform = TVPlatform.bravia

    private let host: String
    private let client: HTTPRequesting
    private let store: TVTokenStoring
    private let timeout: TimeInterval
    private let codeCache = CodeCache()

    init(
        host: String,
        client: HTTPRequesting = LocalHTTPClient(),
        store: TVTokenStoring = KeychainTokenStore(),
        timeout: TimeInterval = 5
    ) {
        self.host = host
        self.client = client
        self.store = store
        self.timeout = timeout
    }

    /// Checks that the host is a Bravia (the interface call needs no sign-in) and that the saved cookie still
    /// works. Throws `TVError.notPaired` without a cookie, or when the TV no longer accepts it.
    func connect() async throws {
        guard cookie() != nil else { throw TVError.notPaired }
        let info = try await rpc(service: "system", method: "getInterfaceInformation", authenticated: false)
        guard info["result"] != nil else { throw TVError.badResponse }
        _ = try await rpc(service: "system", method: "getPowerStatus")
    }

    func send(_ key: KeyCommand) async throws {
        if key == .power {
            try await togglePower()
            return
        }
        try await sendIRCC(names: Self.irccNames(for: key), key: key)
    }

    /// The TV's own power state decides: it is turned off if it is on, and on if it is off (the TV's
    /// "remote start" setting has to allow turning it on).
    private func togglePower() async throws {
        let status = try await rpc(service: "system", method: "getPowerStatus")
        let current = ((status["result"] as? [Any])?.first as? [String: Any])?["status"] as? String
        let isOn = current == "active"
        _ = try await rpc(service: "system", method: "setPowerStatus", params: [["status": !isOn]])
    }

    // MARK: - Text and apps

    /// `setTextForm` with the text as the parameter (pybravia). Backspace has no call here.
    func send(_ text: TextCommand) async throws {
        switch text {
        case .insert(let string):
            guard !string.isEmpty else { return }
            _ = try await rpc(service: "appControl", method: "setTextForm", params: [string])
        case .backspace:
            throw TVError.unsupportedText
        case .enter:
            try await sendIRCC(names: ["Confirm"], key: .select)
        }
    }

    /// The installed apps: `getApplicationList`, each with a title and a uri.
    func apps() async throws -> [TVApp] {
        let reply = try await rpc(service: "appControl", method: "getApplicationList")
        guard let result = reply["result"] as? [Any], let list = result.first as? [[String: Any]] else {
            throw TVError.badResponse
        }
        return list.compactMap { item in
            guard let uri = item["uri"] as? String, let title = item["title"] as? String, !title.isEmpty else { return nil }
            return TVApp(id: uri, name: title)
        }
    }

    func launch(_ app: TVApp) async throws {
        do {
            _ = try await rpc(service: "appControl", method: "setActiveApp", params: [["uri": app.id]])
        } catch TVError.refused {
            throw TVError.appUnavailable
        }
    }

    /// Casting goes through the TV's DLNA renderer (DLNACastSession.swift). UNVERIFIED on a Sony.
    func startCasting() async throws -> any CastSession {
        let session = DLNACastSession(host: host)
        try await session.open()
        return session
    }

    /// The MAC address in `getSystemInformation`, for Wake-on-LAN.
    func hardwareAddresses() async -> [MACAddress] {
        guard let reply = try? await rpc(service: "system", method: "getSystemInformation"),
              let result = reply["result"],
              let data = try? JSONSerialization.data(withJSONObject: result),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }
        return MACAddress.all(in: text)
    }

    func disconnect() async {}

    // MARK: - Keys

    /// Sony's usual IRCC names for each key, in the order they are tried. Empty when Sony has none. From
    /// memory, UNVERIFIED: the TV's own list decides which exist.
    static func irccNames(for key: KeyCommand) -> [String] {
        switch key {
        case .volumeUp: return ["VolumeUp"]
        case .volumeDown: return ["VolumeDown"]
        case .mute: return ["Mute"]
        case .channelUp: return ["ChannelUp"]
        case .channelDown: return ["ChannelDown"]
        case .up: return ["Up"]
        case .down: return ["Down"]
        case .left: return ["Left"]
        case .right: return ["Right"]
        case .select: return ["Confirm", "DpadCenter"]
        case .back: return ["Return"]
        case .home: return ["Home"]
        case .menu: return ["Options"]
        case .rewind: return ["Rewind"]
        case .fastForward: return ["Forward"]
        case .input: return ["Input"]
        case .guide: return ["EPG", "GGuide"]
        case .info: return ["Display"]
        case .liveTV: return ["Tv"]
        case .hdmi1: return ["Hdmi1"]
        case .hdmi2: return ["Hdmi2"]
        case .hdmi3: return ["Hdmi3"]
        case .hdmi4: return ["Hdmi4"]
        case .play: return ["Play"]
        case .pause: return ["Pause"]
        case .stop: return ["Stop"]
        case .next: return ["Next"]
        case .previous: return ["Prev"]
        case .red: return ["Red"]
        case .green: return ["Green"]
        case .yellow: return ["Yellow"]
        case .blue: return ["Blue"]
        case .exit: return ["Exit"]
        case .subtitles: return ["SubTitle", "ClosedCaption"]
        case .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9:
            return ["Num\(key.digitValue ?? 0)"]
        case .power, .playPause, .settings: return []
        }
    }

    /// Whether the remote shows this key. Power goes through the TV's power state, not a code.
    static func supports(_ key: KeyCommand) -> Bool {
        key == .power || !irccNames(for: key).isEmpty
    }

    private func sendIRCC(names: [String], key: KeyCommand) async throws {
        let codes = try await remoteCodes()
        guard let code = names.compactMap({ codes[$0] }).first else {
            throw TVError.unsupportedKey(key)
        }
        guard let url = URL(string: "http://\(host)/sony/IRCC"), let cookie = cookie() else {
            throw TVError.notPaired
        }
        let response = try await send(HTTPRequest(
            url: url,
            method: "POST",
            headers: [
                "Content-Type": "text/xml; charset=UTF-8",
                "SOAPACTION": BraviaMessages.irccAction,
                "Cookie": "auth=\(cookie)"
            ],
            body: BraviaMessages.irccEnvelope(code: code),
            timeout: timeout
        ))
        guard (200...299).contains(response.statusCode) else { throw TVError.refused }
    }

    /// The TV's code list, fetched once per connection.
    private func remoteCodes() async throws -> [String: String] {
        if let cached = codeCache.value { return cached }
        let data = try await rpcData(service: "system", method: "getRemoteControllerInfo", params: [])
        let codes = BraviaMessages.irccCodes(from: data)
        guard !codes.isEmpty else { throw TVError.badResponse }
        codeCache.value = codes
        return codes
    }

    // MARK: - Requests

    private func cookie() -> String? {
        store.token(for: host, platform: .bravia)
    }

    /// One JSON-RPC call, parsed. A `{"error": [...]}` answer is `TVError.refused`.
    private func rpc(service: String, method: String, params: [Any] = [], authenticated: Bool = true) async throws -> [String: Any] {
        let data = try await rpcData(service: service, method: method, params: params, authenticated: authenticated)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TVError.badResponse
        }
        if json["error"] != nil { throw TVError.refused }
        return json
    }

    private func rpcData(service: String, method: String, params: [Any], authenticated: Bool = true) async throws -> Data {
        guard let url = URL(string: "http://\(host)/sony/\(service)"),
              let body = BraviaMessages.rpc(method: method, params: params) else {
            throw TVError.unreachable
        }
        var headers = ["Content-Type": "application/json"]
        if authenticated {
            guard let cookie = cookie() else { throw TVError.notPaired }
            headers["Cookie"] = "auth=\(cookie)"
        }
        let response = try await send(HTTPRequest(url: url, method: "POST", headers: headers, body: body, timeout: timeout))
        guard (200...299).contains(response.statusCode) else { throw TVError.badResponse }
        return response.data
    }

    /// Sends a request. A 401 or 403 means the cookie is gone (it expires), so the phone has to sign in again.
    private func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard LocalTrustPolicy.shouldTrust(host: host) else { throw TVError.unreachable }
        let response: HTTPResponse
        do {
            response = try await client.send(request)
        } catch {
            throw ApprovalWait.tvError(from: error)
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw TVError.notPaired
        }
        return response
    }
}

/// The TV's code list, shared by the copies of the controller. Safe across threads.
private nonisolated final class CodeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var codes: [String: String]?

    var value: [String: String]? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return codes
        }
        set {
            lock.lock()
            codes = newValue
            lock.unlock()
        }
    }
}
