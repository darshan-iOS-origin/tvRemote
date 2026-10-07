//
//  RokuController.swift
//  tvRemoteDemo
//
//  Roku External Control Protocol over plain HTTP on the local network (README.md, Roku quick
//  reference): `POST http://<ip>:8060/keypress/<Key>`. No pairing is needed.
//
//  The key codes follow the Roku client in SmartCastKit, Transports/RokuTransport.swift
//  (https://github.com/yuri-rod/smart-tv-remote-swift, MIT, copyright 2026 Yuri Barreira). Only the
//  key names are used, no code. Power, volume and channel keys work on Roku TVs but not on every
//  Roku streaming player (README).
//

import Foundation

nonisolated struct RokuController: TVController {
    let platform = TVPlatform.roku

    private let host: String
    private let client: HTTPRequesting
    private let timeout: TimeInterval

    init(host: String, client: HTTPRequesting = LocalHTTPClient(), timeout: TimeInterval = 3) {
        self.host = host
        self.client = client
        self.timeout = timeout
    }

    /// Roku is stateless, so connecting only checks that the TV answers like a Roku. That also shows
    /// early when network control is switched off.
    func connect() async throws {
        let response = try await request(path: "query/device-info", method: "GET")
        guard RokuDeviceInfoParser.parse(response.data) != nil else {
            throw TVError.badResponse
        }
    }

    func send(_ key: KeyCommand) async throws {
        // Live TV is not a key on a Roku: it launches the TV's tuner input, `tvinput.dtv`, as the channel
        // call does. UNVERIFIED, from memory. Only a Roku TV with a tuner has it.
        if key == .liveTV {
            _ = try await request(path: "launch/tvinput.dtv", method: "POST")
            return
        }
        guard let code = Self.keyCode(for: key) else {
            throw TVError.unsupportedKey(key)
        }
        _ = try await request(path: "keypress/\(code)", method: "POST")
    }

    /// Text goes one character at a time as `Lit_<character>` (README, Roku quick reference, and
    /// SmartCastKit). UNVERIFIED, TODO: confirm the `Backspace` and `Enter` key names against Roku's
    /// External Control Protocol documentation.
    func send(_ text: TextCommand) async throws {
        switch text {
        case .insert(let string):
            for character in string {
                guard let encoded = String(character).addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
                    throw TVError.unsupportedCharacter
                }
                _ = try await request(path: "keypress/Lit_\(encoded)", method: "POST")
            }
        case .backspace:
            _ = try await request(path: "keypress/Backspace", method: "POST")
        case .enter:
            _ = try await request(path: "keypress/Enter", method: "POST")
        }
    }

    /// The apps installed on the Roku (`GET /query/apps`).
    func apps() async throws -> [TVApp] {
        let response = try await request(path: "query/apps", method: "GET")
        guard let apps = RokuAppsParser.parse(response.data) else {
            throw TVError.badResponse
        }
        return apps.map { TVApp(id: $0.id, name: $0.name) }
    }

    /// Switches a Roku TV to a live channel: `POST /launch/tvinput.dtv?ch=<number>`. UNVERIFIED, from
    /// memory (Roku's documentation could not be read). Only a Roku TV with a tuner has channels.
    func openChannel(_ number: String) async throws {
        guard ChannelNumber.isValid(number) else {
            throw TVError.unsupportedCharacter
        }
        _ = try await request(path: "launch/tvinput.dtv?ch=\(number)", method: "POST")
    }

    /// `POST /launch/<appId>` (README, Roku quick reference).
    func launch(_ app: TVApp) async throws {
        guard let id = app.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            throw TVError.appUnavailable
        }
        _ = try await request(path: "launch/\(id)", method: "POST")
    }

    /// Casts through the "Play on Roku" channel (RokuCastSession.swift).
    func startCasting() async throws -> any CastSession {
        RokuCastSession(host: host, client: client)
    }

    /// `wifi-mac` and `ethernet-mac` in the device-info reply. UNVERIFIED, from memory: TODO confirm the
    /// field names against Roku's External Control Protocol documentation.
    func hardwareAddresses() async -> [MACAddress] {
        guard let response = try? await request(path: "query/device-info", method: "GET"),
              let info = RokuDeviceInfoParser.parse(response.data) else {
            return []
        }
        var found: [MACAddress] = []
        for leaf in info.fields where leaf.key.hasSuffix("wifi-mac") || leaf.key.hasSuffix("ethernet-mac") {
            if let address = MACAddress(leaf.value), !found.contains(address) {
                found.append(address)
            }
        }
        return found
    }

    func disconnect() async {}

    /// The Roku key for a brand-neutral key.
    static func keyCode(for key: KeyCommand) -> String? {
        switch key {
        case .power: return "Power"
        case .volumeUp: return "VolumeUp"
        case .volumeDown: return "VolumeDown"
        case .mute: return "VolumeMute"
        case .channelUp: return "ChannelUp"
        case .channelDown: return "ChannelDown"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .select: return "Select"
        case .back: return "Back"
        case .home: return "Home"
        // My judgement, not from a source: Roku has no Menu key. `Info` is the `*` options button.
        case .menu: return "Info"
        case .rewind: return "Rev"
        // `Play` toggles between playing and paused.
        case .playPause: return "Play"
        case .fastForward: return "Fwd"
        // Roku's own input keys. UNVERIFIED, from memory (Roku's documentation could not be read). Only a
        // Roku TV has HDMI ports to switch.
        case .hdmi1: return "InputHDMI1"
        case .hdmi2: return "InputHDMI2"
        case .hdmi3: return "InputHDMI3"
        case .hdmi4: return "InputHDMI4"
        // The Google TV layout's keys. A Roku has no equivalent we can confirm.
        case .input, .settings, .guide, .info, .liveTV: return nil
        // Roku's one `Play` key is the Play / Pause key above, and it has none of these.
        case .play, .pause, .stop, .next, .previous, .red, .green, .yellow, .blue, .exit, .subtitles: return nil
        // Roku has no number keys. A digit is typed as a character, so it only reaches a focused text or
        // PIN field, and changes no channel.
        case .digit0, .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9:
            return "Lit_\(key.digitValue ?? 0)"
        }
    }

    // MARK: - Requests

    private func request(path: String, method: String) async throws -> HTTPResponse {
        guard let url = URL(string: "http://\(host):\(ControlPorts.rokuECP)/\(path)") else {
            throw TVError.unreachable
        }

        let response: HTTPResponse
        do {
            response = try await client.send(HTTPRequest(url: url, method: method, timeout: timeout))
        } catch let error as URLError where error.code == .timedOut {
            throw TVError.timedOut
        } catch {
            throw TVError.unreachable
        }

        switch response.statusCode {
        case 200...299: return response
        // The TV's "control by mobile apps" setting is set to a mode that refuses this app.
        case 403: throw TVError.refused
        default: throw TVError.badResponse
        }
    }
}
