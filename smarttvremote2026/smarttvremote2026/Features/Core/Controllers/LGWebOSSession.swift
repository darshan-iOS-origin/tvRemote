//
//  LGWebOSSession.swift
//  tvRemoteDemo
//
//  One connection to an LG webOS TV (SSAP over WebSocket): register this phone, then open the TV's
//  pointer input socket, which is what carries the remote's buttons.
//
//  The protocol facts come from lgtv2 (https://github.com/hobbyquaker/lgtv2, MIT, copyright
//  Sebastian Raff) and PyWebOSTV (https://github.com/supersaiyanmode/PyWebOSTV, MIT, copyright 2017
//  Srivatsan Iyer): register with a `client-key`, the first time the TV shows a prompt and then sends
//  a key; ask `ssap://com.webos.service.networkinput/getPointerInputSocket` for a `socketPath`; send
//  `type:button` / `name:<BUTTON>` text frames to it. No code is copied. We use the unsigned
//  manifest that lgtv2 falls back to, because its signed one is a shared LG sample signature.
//
//  SmartCastKit's LG client is not used: its registration lacks the mouse-and-keyboard permission
//  the pointer socket needs, and it has no way to send the d-pad.
//
//  UNVERIFIED on a real TV: that an unsigned registration is granted CONTROL_MOUSE_AND_KEYBOARD on
//  every webOS version, and which of ports 3001 (wss) and 3000 (ws) a given TV answers.
//

import Foundation

nonisolated actor LGWebOSSession {
    /// lgtv2 tries the secure port first (2018 and newer firmware), then the plain one.
    private static let candidateURLs = ["wss://%@:3001", "ws://%@:3000"]
    private static let connectTimeout: TimeInterval = 5
    private static let requestTimeout: TimeInterval = 8

    /// The permission names in lgtv2's pairing manifest, plus the two it adds for an unsigned one.
    private static let permissions = [
        "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP", "CLOSE", "TEST_OPEN", "TEST_PROTECTED", "CONTROL_AUDIO",
        "CONTROL_DISPLAY", "CONTROL_INPUT_JOYSTICK", "CONTROL_INPUT_MEDIA_RECORDING",
        "CONTROL_INPUT_MEDIA_PLAYBACK", "CONTROL_INPUT_TV", "CONTROL_POWER", "READ_APP_STATUS",
        "READ_CURRENT_CHANNEL", "READ_INPUT_DEVICE_LIST", "READ_NETWORK_STATE", "READ_RUNNING_APPS",
        "READ_TV_CHANNEL_LIST", "WRITE_NOTIFICATION_TOAST", "READ_POWER_STATE", "READ_COUNTRY_INFO",
        "READ_SETTINGS", "CONTROL_TV_SCREEN", "CONTROL_TV_STANBY", "CONTROL_FAVORITE_GROUP",
        "CONTROL_USER_INFO", "CHECK_BLUETOOTH_DEVICE", "CONTROL_BLUETOOTH", "CONTROL_TIMER_INFO",
        "STB_INTERNAL_CONNECTION", "CONTROL_RECORDING", "READ_RECORDING_STATE", "WRITE_RECORDING_LIST",
        "READ_RECORDING_LIST", "READ_RECORDING_SCHEDULE", "WRITE_RECORDING_SCHEDULE",
        "READ_STORAGE_DEVICE_LIST", "READ_TV_PROGRAM_INFO", "CONTROL_BOX_CHANNEL", "READ_TV_ACR_AUTH_TOKEN",
        "READ_TV_CONTENT_STATE", "READ_TV_CURRENT_TIME", "ADD_LAUNCHER_CHANNEL", "SET_CHANNEL_SKIP",
        "RELEASE_CHANNEL_SKIP", "CONTROL_CHANNEL_BLOCK", "DELETE_SELECT_CHANNEL", "CONTROL_CHANNEL_GROUP",
        "SCAN_TV_CHANNELS", "CONTROL_TV_POWER", "CONTROL_WOL", "CONTROL_INPUT_TEXT",
        "CONTROL_MOUSE_AND_KEYBOARD"
    ]

    private let host: String
    private let store: TVTokenStoring
    private let approvalTimeout: TimeInterval

    private var session: URLSession?
    private var main: URLSessionWebSocketTask?
    private var pointer: URLSessionWebSocketTask?
    private var requestCounter = 0

    init(host: String, store: TVTokenStoring, approvalTimeout: TimeInterval = ApprovalWait.defaultTimeout) {
        self.host = host
        self.store = store
        self.approvalTimeout = approvalTimeout
    }

    var isOpen: Bool {
        pointer != nil
    }

    /// Registers with the TV and opens the pointer socket. The first time, this waits for the user to
    /// accept the prompt on the TV. Throws a `TVError`.
    func open() async throws {
        close()
        // Certificates are accepted without checking, so only ever talk to a local address.
        guard LocalTrustPolicy.shouldTrust(host: host) else {
            throw TVError.unreachable
        }
        let newSession = URLSession(configuration: .ephemeral, delegate: LocalTrustDelegate(), delegateQueue: nil)
        session = newSession
        do {
            let registered = try await register(using: newSession)
            main = registered
            pointer = try await openPointerSocket(over: registered, using: newSession)
        } catch {
            close()
            throw Self.tvError(from: error)
        }
    }

    /// Presses a button on the TV's remote, for example `UP` or `VOLUMEUP`. A dead connection is
    /// reopened once. Throws a `TVError`.
    func press(_ button: String) async throws {
        try await sendPointerFrame("type:button\nname:\(button)\n\n")
    }

    /// Moves the cursor: `type:move` with `dx` and `dy` (lgtv2's README, `sock.send('move', {dx, dy})`).
    func movePointer(dx: Int, dy: Int) async throws {
        try await sendPointerFrame("type:move\ndx:\(dx)\ndy:\(dy)\n\n")
    }

    /// Clicks: `type:click` (lgtv2's README).
    func click() async throws {
        try await sendPointerFrame("type:click\n\n")
    }

    /// Scrolls: `type:scroll` with `dx` and `dy`. UNVERIFIED, from memory: lgtv2's README does not list it.
    func scroll(dx: Int, dy: Int) async throws {
        try await sendPointerFrame("type:scroll\ndx:\(dx)\ndy:\(dy)\n\n")
    }

    /// Sends one frame on the pointer socket. A dead connection is reopened once.
    private func sendPointerFrame(_ frame: String) async throws {
        if pointer != nil {
            do {
                try await pointer?.send(.string(frame))
                return
            } catch {
                // The TV closed the connection since the last key. Open a new one below.
            }
        }
        try await open()
        do {
            try await pointer?.send(.string(frame))
        } catch {
            close()
            throw Self.tvError(from: error)
        }
    }

    /// Sends an SSAP request that needs no answer, for example `ssap://system/turnOff`.
    func request(_ uri: String) async throws {
        try await sendRequest(uri: uri, payload: nil)
    }

    /// Types into the text field focused on the TV (PyWebOSTV `InputControl`).
    func insertText(_ text: String) async throws {
        try await sendRequest(uri: "ssap://com.webos.service.ime/insertText", payload: ["text": text, "replace": 0])
    }

    func deleteCharacters(count: Int) async throws {
        try await sendRequest(uri: "ssap://com.webos.service.ime/deleteCharacters", payload: ["count": count])
    }

    func sendEnterKey() async throws {
        try await sendRequest(uri: "ssap://com.webos.service.ime/sendEnterKey", payload: nil)
    }

    /// The apps installed on the TV: `ssap://com.webos.applicationManager/listLaunchPoints` (lgtv2).
    /// UNVERIFIED: the reply is read tolerantly, as `launchPoints` or `apps`, each with an `id` and a
    /// `title`.
    func listApps() async throws -> [TVApp] {
        let reply = try await roundTrip(uri: "ssap://com.webos.applicationManager/listLaunchPoints", payload: nil)
        let answer = reply["payload"] as? [String: Any]
        let entries = (answer?["launchPoints"] as? [[String: Any]]) ?? (answer?["apps"] as? [[String: Any]]) ?? []
        return entries.compactMap { entry in
            guard let id = entry["id"] as? String,
                  let name = (entry["title"] as? String) ?? (entry["name"] as? String),
                  !name.isEmpty else {
                return nil
            }
            return TVApp(id: id, name: name)
        }
    }

    /// The Wi-Fi and wired MAC addresses from `ssap://com.webos.service.connectionmanager/getinfo` (the
    /// request is listed in lgtv2's README, and lgtv2 wakes the TV with the addresses it returns).
    /// UNVERIFIED on a real TV: the field names are not relied on, every string in the reply that looks
    /// like a MAC address is taken. Empty if the request fails.
    func hardwareAddresses() async -> [MACAddress] {
        guard let reply = try? await roundTrip(uri: "ssap://com.webos.service.connectionmanager/getinfo", payload: nil),
              let answer = reply["payload"] else {
            return []
        }
        var found: [MACAddress] = []
        Self.collectMACs(in: answer, into: &found)
        return found
    }

    private static func collectMACs(in value: Any, into found: inout [MACAddress]) {
        if let text = value as? String {
            for address in MACAddress.all(in: text) where !found.contains(address) {
                found.append(address)
            }
        } else if let object = value as? [String: Any] {
            for key in object.keys.sorted() {
                if let child = object[key] {
                    collectMACs(in: child, into: &found)
                }
            }
        } else if let list = value as? [Any] {
            for child in list {
                collectMACs(in: child, into: &found)
            }
        }
    }

    /// Switches to an input such as `HDMI_2`: `ssap://tv/switchInput` with `{inputId}` (lgtv2's README
    /// gives `HDMI_2` as the example; `HDMI_1`, `HDMI_3` and `HDMI_4` follow the same pattern, UNVERIFIED).
    func switchInput(_ id: String) async throws {
        do {
            _ = try await roundTrip(uri: "ssap://tv/switchInput", payload: ["inputId": id])
        } catch TVError.refused {
            throw TVError.inputFailed
        }
    }

    /// Switches to a channel: `ssap://tv/openChannel` with `{channelNumber}` (lgtv2's README).
    func openChannel(_ number: String) async throws {
        do {
            _ = try await roundTrip(uri: "ssap://tv/openChannel", payload: ["channelNumber": number])
        } catch TVError.refused {
            throw TVError.channelFailed
        }
    }

    /// `ssap://system.launcher/launch` with the app's id (lgtv2, PyWebOSTV).
    func launchApp(id: String) async throws {
        do {
            _ = try await roundTrip(uri: "ssap://system.launcher/launch", payload: ["id": id])
        } catch TVError.refused {
            throw TVError.appUnavailable
        }
    }

    /// Sends a request and waits for the reply with the same id. Throws `TVError.refused` if the TV
    /// answers with an error.
    private func roundTrip(uri: String, payload: [String: Any]?) async throws -> [String: Any] {
        if main == nil {
            try await open()
        }
        guard let socket = main else {
            throw TVError.notConnected
        }
        requestCounter += 1
        let id = "request_\(requestCounter)"
        var message: [String: Any] = ["type": "request", "id": id, "uri": uri]
        if let payload {
            message["payload"] = payload
        }
        do {
            try await socket.send(.string(try Self.json(message)))
            for _ in 0..<30 {
                let reply = try await Self.receiveJSON(on: socket, timeout: Self.requestTimeout)
                // Replies to earlier requests that nobody waited for are skipped.
                guard reply["id"] as? String == id else { continue }
                let answer = reply["payload"] as? [String: Any]
                if reply["type"] as? String == "error" || answer?["returnValue"] as? Bool == false {
                    throw TVError.refused
                }
                return reply
            }
            throw TVError.badResponse
        } catch TVError.refused {
            throw TVError.refused
        } catch {
            close()
            throw Self.tvError(from: error)
        }
    }

    private func sendRequest(uri: String, payload: [String: Any]?) async throws {
        if main == nil {
            try await open()
        }
        requestCounter += 1
        var message: [String: Any] = ["type": "request", "id": "request_\(requestCounter)", "uri": uri]
        if let payload {
            message["payload"] = payload
        }
        do {
            try await main?.send(.string(try Self.json(message)))
        } catch {
            close()
            throw Self.tvError(from: error)
        }
    }

    func close() {
        pointer?.cancel(with: .goingAway, reason: nil)
        main?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        pointer = nil
        main = nil
        session = nil
    }

    // MARK: - Registering

    private func register(using session: URLSession) async throws -> URLSessionWebSocketTask {
        let message = try Self.json(Self.registration(clientKey: store.token(for: host, platform: .webOS)))
        var lastError: Error = TVError.unreachable

        for template in Self.candidateURLs {
            guard let url = URL(string: String(format: template, host)) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = Self.connectTimeout
            let task = session.webSocketTask(with: request)
            task.resume()
            do {
                try await task.send(.string(message))
                try await waitForRegistered(on: task)
                return task
            } catch TVError.denied {
                task.cancel(with: .goingAway, reason: nil)
                throw TVError.denied
            } catch TVError.awaitingApproval {
                task.cancel(with: .goingAway, reason: nil)
                throw TVError.awaitingApproval
            } catch {
                // This port did not answer. Try the other one.
                task.cancel(with: .goingAway, reason: nil)
                lastError = error
            }
        }
        throw Self.tvError(from: lastError)
    }

    private func waitForRegistered(on task: URLSessionWebSocketTask) async throws {
        let deadline = Date().addingTimeInterval(approvalTimeout)
        while true {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { throw TVError.awaitingApproval }
            let reply: [String: Any]
            do {
                reply = try await Self.receiveJSON(on: task, timeout: remaining)
            } catch TVError.timedOut {
                throw TVError.awaitingApproval
            }
            switch reply["type"] as? String {
            case "registered":
                guard let key = (reply["payload"] as? [String: Any])?["client-key"] as? String, !key.isEmpty else {
                    throw TVError.badResponse
                }
                store.save(key, for: host, platform: .webOS)
                return
            case "error":
                // For example "403 User denied access" when the prompt is declined.
                throw TVError.denied
            default:
                // The first reply says the TV is showing its prompt. Keep waiting for the user.
                continue
            }
        }
    }

    // MARK: - Pointer socket

    private func openPointerSocket(
        over main: URLSessionWebSocketTask,
        using session: URLSession
    ) async throws -> URLSessionWebSocketTask {
        requestCounter += 1
        let id = "request_\(requestCounter)"
        let message: [String: Any] = [
            "type": "request",
            "id": id,
            "uri": "ssap://com.webos.service.networkinput/getPointerInputSocket"
        ]
        try await main.send(.string(try Self.json(message)))

        for _ in 0..<20 {
            let reply = try await Self.receiveJSON(on: main, timeout: Self.requestTimeout)
            guard reply["id"] as? String == id else { continue }
            let answer = reply["payload"] as? [String: Any]
            if reply["type"] as? String == "error" || answer?["returnValue"] as? Bool == false {
                throw TVError.refused
            }
            guard let path = answer?["socketPath"] as? String,
                  let url = URL(string: path),
                  url.scheme == "ws" || url.scheme == "wss",
                  LocalTrustPolicy.shouldTrust(host: url.host ?? "") else {
                throw TVError.badResponse
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = Self.connectTimeout
            let task = session.webSocketTask(with: request)
            task.resume()
            return task
        }
        throw TVError.badResponse
    }

    // MARK: - Messages

    private static func registration(clientKey: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "forcePairing": false,
            "pairingType": "PROMPT",
            "manifest": [
                "manifestVersion": 1,
                "appVersion": "1.0",
                "permissions": permissions
            ] as [String: Any]
        ]
        if let clientKey, !clientKey.isEmpty {
            payload["client-key"] = clientKey
        }
        return ["type": "register", "id": "register_0", "payload": payload]
    }

    private static func json(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw TVError.badResponse
        }
        return text
    }

    /// Reads the next JSON message. Throws `TVError.timedOut` if none arrives in time, which also
    /// closes the socket so the read ends.
    private static func receiveJSON(on task: URLSessionWebSocketTask, timeout: TimeInterval) async throws -> [String: Any] {
        while true {
            let message = try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
                group.addTask { try await task.receive() }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    task.cancel(with: .goingAway, reason: nil)
                    throw TVError.timedOut
                }
                defer { group.cancelAll() }
                guard let first = try await group.next() else {
                    throw TVError.unreachable
                }
                return first
            }
            let data: Data
            switch message {
            case .string(let text): data = Data(text.utf8)
            case .data(let bytes): data = bytes
            @unknown default: continue
            }
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return object
            }
        }
    }

    private static func tvError(from error: Error) -> TVError {
        ApprovalWait.tvError(from: error)
    }
}
