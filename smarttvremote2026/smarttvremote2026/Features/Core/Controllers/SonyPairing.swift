//
//  SonyPairing.swift
//  tvRemoteDemo
//
//  Sony Bravia sign-in with the PIN the TV shows (messages: BraviaMessages.swift). `start` calls
//  `actRegister` without credentials: the TV answers 401 and shows a four-digit PIN. `submit` calls it
//  again with the PIN as the Basic-auth password, and the TV answers with an `auth` cookie, which is kept
//  in the Keychain and sent with every later request. The pre-shared-key mode is not supported.
//
//  UNVERIFIED on a real Sony: the exact answers. The TV needs IP control switched on, with authentication
//  set to "Normal" (Settings, Network, IP control).
//

import Foundation

nonisolated struct SonyPairing: TVPairing {
    let platform = TVPlatform.bravia

    private let client: HTTPRequesting
    private let store: TVTokenStoring
    private let timeout: TimeInterval
    private let deviceID: @Sendable () -> String

    init(
        client: HTTPRequesting = LocalHTTPClient(),
        store: TVTokenStoring = KeychainTokenStore(),
        timeout: TimeInterval = 8,
        deviceID: @escaping @Sendable () -> String = VizioPairing.installID
    ) {
        self.client = client
        self.store = store
        self.timeout = timeout
        self.deviceID = deviceID
    }

    func start(device: TVDevice) async throws -> PairingChallenge {
        let id = clientID()
        let response = try await register(host: device.host, clientID: id, authorization: nil)
        // 401 is the answer that goes with a PIN on the screen. Anything else means IP control is off, or the
        // TV is set to the pre-shared-key mode, which this app does not use.
        guard response.statusCode == 401 else {
            throw PairingError.rejected
        }
        return PairingChallenge(platform: .bravia, token: "", deviceID: id, port: 80, host: device.host)
    }

    /// Sends the PIN. The PIN goes to the TV and nowhere else: it is never logged or stored.
    func submit(code: String, challenge: PairingChallenge) async throws {
        let pin = PairingCodeFormat.sony.normalized(code)
        let response = try await register(
            host: challenge.host,
            clientID: challenge.deviceID,
            authorization: BraviaMessages.basicAuthorization(pin: pin)
        )
        switch response.statusCode {
        case 200...299:
            guard let cookie = BraviaMessages.authCookie(fromSetCookie: response.headers["set-cookie"]) else {
                throw PairingError.badResponse
            }
            store.save(cookie, for: challenge.host, platform: .bravia)
        case 401, 403:
            throw PairingError.wrongCode
        default:
            throw PairingError.rejected
        }
    }

    private func clientID() -> String {
        "TVRemote:\(deviceID())"
    }

    private func register(host: String, clientID: String, authorization: String?) async throws -> HTTPResponse {
        guard LocalTrustPolicy.shouldTrust(host: host),
              let url = URL(string: "http://\(host)/sony/accessControl"),
              let body = BraviaMessages.actRegister(clientID: clientID) else {
            throw PairingError.unreachable
        }
        var headers = ["Content-Type": "application/json"]
        if let authorization { headers["Authorization"] = authorization }
        do {
            return try await client.send(HTTPRequest(url: url, method: "POST", headers: headers, body: body, timeout: timeout))
        } catch let error as URLError where error.code == .timedOut {
            throw PairingError.timedOut
        } catch {
            throw PairingError.unreachable
        }
    }
}
