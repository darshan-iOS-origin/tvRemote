//
//  FireTVPairing.swift
//  tvRemoteDemo
//
//  Amazon Fire TV sign-in with the four-digit PIN the TV shows. `POST /v1/FireTV/pin/display` makes the TV
//  show a PIN, and `POST /v1/FireTV/pin/verify` with `{"pin": ...}` answers `{"description": "<token>"}`.
//  The token is kept in the Keychain and sent as `X-Client-Token` (FireTVController.swift).
//
//  The calls come from the community documentation of Amazon's own remote app: hms-firetv (MIT, Copyright (c)
//  2026 HMS Homelab). FireTVRest, which has no licence, was read for facts only: nothing is copied from it.
//  The API key is the fixed value that the official app sends, recovered by reverse engineering. Amazon
//  publishes none of this and can change it at any time. UNVERIFIED on a real Fire TV.
//

import Foundation

nonisolated enum FireTVAPI {
    static let port: UInt16 = 8080
    /// The port of the plain-HTTP call that wakes a sleeping Fire TV.
    static let wakePort: UInt16 = 8009
    /// The key the official Fire TV remote app sends in `X-Api-Key`. UNVERIFIED on a device.
    static let apiKey = "0987654321"
    static let friendlyName = "TV Remote"

    /// `https://<host>:8080/<path>`.
    static func url(host: String, path: String) -> URL? {
        URL(string: "https://\(host):\(port)/\(path)")
    }

    static func headers(token: String?) -> [String: String] {
        var headers = ["X-Api-Key": apiKey, "Content-Type": "application/json"]
        if let token { headers["X-Client-Token"] = token }
        return headers
    }

    static func displayBody() -> Data? {
        try? JSONSerialization.data(withJSONObject: ["friendlyName": friendlyName])
    }

    static func verifyBody(pin: String) -> Data? {
        try? JSONSerialization.data(withJSONObject: ["pin": pin])
    }

    /// The client token in the answer to `pin/verify`: `{"description": "<token>"}`. Public for checking.
    static func token(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["description"] as? String, !token.isEmpty else {
            return nil
        }
        return token
    }
}

nonisolated struct FireTVPairing: TVPairing {
    let platform = TVPlatform.fireTV

    private let client: HTTPRequesting
    private let store: TVTokenStoring
    private let timeout: TimeInterval

    init(client: HTTPRequesting = LocalHTTPClient(), store: TVTokenStoring = KeychainTokenStore(), timeout: TimeInterval = 8) {
        self.client = client
        self.store = store
        self.timeout = timeout
    }

    func start(device: TVDevice) async throws -> PairingChallenge {
        let response = try await post(host: device.host, path: "v1/FireTV/pin/display", body: FireTVAPI.displayBody())
        guard (200...299).contains(response.statusCode) else {
            throw PairingError.rejected
        }
        return PairingChallenge(platform: .fireTV, token: "", deviceID: "", port: FireTVAPI.port, host: device.host)
    }

    /// Sends the PIN. The PIN and the token go to the TV and the Keychain only: they are never logged.
    func submit(code: String, challenge: PairingChallenge) async throws {
        let pin = PairingCodeFormat.fireTV.normalized(code)
        let response = try await post(host: challenge.host, path: "v1/FireTV/pin/verify", body: FireTVAPI.verifyBody(pin: pin))
        switch response.statusCode {
        case 200...299:
            guard let token = FireTVAPI.token(from: response.data) else {
                throw PairingError.badResponse
            }
            store.save(token, for: challenge.host, platform: .fireTV)
        case 400, 401, 403, 404:
            throw PairingError.wrongCode
        default:
            throw PairingError.rejected
        }
    }

    private func post(host: String, path: String, body: Data?) async throws -> HTTPResponse {
        guard LocalTrustPolicy.shouldTrust(host: host),
              let url = FireTVAPI.url(host: host, path: path),
              let body else {
            throw PairingError.unreachable
        }
        do {
            return try await client.send(HTTPRequest(
                url: url, method: "POST", headers: FireTVAPI.headers(token: nil), body: body, timeout: timeout
            ))
        } catch let error as URLError where error.code == .timedOut {
            throw PairingError.timedOut
        } catch {
            throw PairingError.unreachable
        }
    }
}
