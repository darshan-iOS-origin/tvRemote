//
//  VizioPairing.swift
//  tvRemoteDemo
//
//  Vizio SmartCast pairing, first half: ask the TV to show its PIN.
//  Source of the calls: heathbar/vizio-smart-cast, index.js (MIT, copyright 2017 Heath Paddock).
//  Only the request shapes are followed. No code is copied.
//    PUT https://<ip>:7345/pairing/start
//        {"DEVICE_NAME": ..., "DEVICE_ID": ...}
//        -> {"STATUS": {"RESULT": "SUCCESS"}, "ITEM": {"PAIRING_REQ_TOKEN": ...}}
//        A RESULT of "BLOCKED" means a pairing request is already showing a PIN.
//  Second half: `PUT /pairing/pair` with DEVICE_ID, CHALLENGE_TYPE 1, RESPONSE_VALUE (the PIN) and
//  PAIRING_REQ_TOKEN, which returns ITEM.AUTH_TOKEN. The token goes in the Keychain and is sent as the
//  `AUTH` header of every later request (see VizioController.swift). The licence of the library is the
//  MIT one in its LICENSE file (its README says ISC).
//  The library has no working cancel call, so a pending request is left to time out on the TV.
//

import Foundation

nonisolated struct VizioPairing: TVPairing {
    let platform = TVPlatform.smartCast

    /// 7345 is the port in the reference library. 9000 is UNVERIFIED (from memory, for newer
    /// models): it is only tried when nothing answers on 7345.
    static let ports: [UInt16] = [7345, 9000]

    /// The name the TV lists for this app.
    static let appName = "TV Remote"

    private static let deviceIDKey = "pairing.installID"

    private let client: HTTPRequesting
    private let store: TVTokenStoring
    private let timeout: TimeInterval
    private let deviceID: @Sendable () -> String

    init(
        client: HTTPRequesting = LocalHTTPClient(),
        store: TVTokenStoring = KeychainTokenStore(),
        timeout: TimeInterval = 5,
        deviceID: @escaping @Sendable () -> String = VizioPairing.installID
    ) {
        self.client = client
        self.store = store
        self.timeout = timeout
        self.deviceID = deviceID
    }

    func start(device: TVDevice) async throws -> PairingChallenge {
        let id = deviceID()
        let body: Data
        do {
            body = try JSONSerialization.data(withJSONObject: [
                "DEVICE_NAME": Self.appName,
                "DEVICE_ID": id
            ])
        } catch {
            throw PairingError.badResponse
        }

        var lastError = PairingError.unreachable
        for port in Self.ports {
            guard let url = URL(string: "https://\(device.host):\(port)/pairing/start") else { continue }
            let request = HTTPRequest(
                url: url,
                method: "PUT",
                headers: ["Content-Type": "application/json"],
                body: body,
                timeout: timeout
            )

            let response: HTTPResponse
            do {
                response = try await client.send(request)
            } catch let error as URLError where error.code == .timedOut {
                lastError = .timedOut
                continue
            } catch {
                // Nothing answered on this port. Try the next one.
                lastError = .unreachable
                continue
            }
            // The TV answered on this port, so its answer is final.
            var challenge = try Self.challenge(from: response.data, deviceID: id, port: port)
            challenge.host = device.host
            return challenge
        }
        throw lastError
    }

    /// Sends the PIN the user read off the TV. Throws `PairingError.wrongCode` when it does not match. The
    /// PIN goes to the TV and nowhere else: it is never logged or stored.
    func submit(code: String, challenge: PairingChallenge) async throws {
        guard LocalTrustPolicy.shouldTrust(host: challenge.host),
              let url = URL(string: "https://\(challenge.host):\(challenge.port)/pairing/pair") else {
            throw PairingError.unreachable
        }
        let pin = PairingCodeFormat.vizio.normalized(code)
        let request = HTTPRequest(
            url: url,
            method: "PUT",
            headers: ["Content-Type": "application/json"],
            body: try Self.pairBody(pin: pin, challenge: challenge),
            timeout: timeout
        )
        let response: HTTPResponse
        do {
            response = try await client.send(request)
        } catch let error as URLError where error.code == .timedOut {
            throw PairingError.timedOut
        } catch {
            throw PairingError.unreachable
        }
        let token = try Self.authToken(from: response.data)
        store.save(token, for: challenge.host, platform: .smartCast)
    }

    /// The body of `PUT /pairing/pair`. The request token is sent as a number when it is all digits, as it
    /// came: UNVERIFIED which type the TV wants. Public for checking.
    static func pairBody(pin: String, challenge: PairingChallenge) throws -> Data {
        let token: Any = Int(challenge.token) ?? challenge.token
        let body: [String: Any] = [
            "DEVICE_ID": challenge.deviceID,
            "CHALLENGE_TYPE": 1,
            "RESPONSE_VALUE": pin,
            "PAIRING_REQ_TOKEN": token
        ]
        do {
            return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        } catch {
            throw PairingError.badResponse
        }
    }

    /// Reads the TV's answer to `/pairing/pair`: the `AUTH_TOKEN` on success. A result that names the
    /// challenge is a wrong PIN: the wording is UNVERIFIED, from memory. Public for checking.
    static func authToken(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["STATUS"] as? [String: Any],
              let result = status["RESULT"] as? String else {
            throw PairingError.badResponse
        }
        switch result.uppercased() {
        case "SUCCESS":
            guard let token = (json["ITEM"] as? [String: Any])?["AUTH_TOKEN"] as? String, !token.isEmpty else {
                throw PairingError.badResponse
            }
            return token
        case "BLOCKED":
            throw PairingError.alreadyPending
        case let other where other.contains("CHALLENGE") || other.contains("INCORRECT") || other.contains("WRONG"):
            throw PairingError.wrongCode
        default:
            throw PairingError.rejected
        }
    }

    /// Reads the TV's answer to `/pairing/start`.
    static func challenge(from data: Data, deviceID: String, port: UInt16) throws -> PairingChallenge {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["STATUS"] as? [String: Any],
              let result = status["RESULT"] as? String else {
            throw PairingError.badResponse
        }

        switch result {
        case "SUCCESS":
            let item = json["ITEM"] as? [String: Any]
            let token: String?
            if let text = item?["PAIRING_REQ_TOKEN"] as? String {
                token = text
            } else if let number = item?["PAIRING_REQ_TOKEN"] as? Int {
                token = String(number)
            } else {
                token = nil
            }
            guard let token else { throw PairingError.badResponse }
            return PairingChallenge(platform: .smartCast, token: token, deviceID: deviceID, port: port)
        case "BLOCKED":
            throw PairingError.alreadyPending
        default:
            throw PairingError.rejected
        }
    }

    /// One id per install, so the TV does not list a new device on every attempt. It is not a
    /// secret, so UserDefaults is fine (tokens belong in the Keychain).
    static func installID() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceIDKey) {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: deviceIDKey)
        return created
    }
}
